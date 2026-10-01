import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../providers.dart';
import '../utils/errors.dart';

/// Create (`note == null`) and edit in one screen.
///
/// The note is passed in rather than re-fetched through a provider family: a
/// family would open a second live Firestore listener per opened note for no
/// benefit, since the list already holds the data.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final Note? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.note?.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final String title = _title.text.trim();
    final String body = _body.text.trim();

    if (title.isEmpty && body.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // Captured before the async gap — this screen is about to pop.
    // ScaffoldMessengerState lives above this route, so it survives the pop and
    // can still surface a failure.
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NoteActions actions = ref.read(noteActionsProvider.notifier);

    // Deliberately not awaited before popping. Firestore commits to the local
    // cache immediately — the note is already in the list, flagged "Saving…" —
    // but the write future does not complete until the server acknowledges,
    // which offline means not until reconnect. Awaiting here would hang the
    // editor indefinitely on a write that has in fact already succeeded locally.
    unawaited(
      actions
          .save(id: widget.note?.id, title: title, body: body)
          .then((bool ok) {
        if (ok) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              describeError(
                ref.read(noteActionsProvider).error ?? 'Save failed',
              ).message,
            ),
          ),
        );
      }),
    );

    navigator.pop();
  }

  void _delete() {
    final Note? note = widget.note;
    if (note == null) return;

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NoteActions actions = ref.read(noteActionsProvider.notifier);

    unawaited(
      actions.delete(note.id).then((bool ok) {
        messenger.clearSnackBars();
        if (!ok) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                describeError(
                  ref.read(noteActionsProvider).error ?? 'Delete failed',
                ).message,
              ),
            ),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted "${note.displayTitle}"'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(actions.restore(note)),
            ),
          ),
        );
      }),
    );

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit note' : 'New note'),
        actions: <Widget>[
          if (isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _title,
              maxLines: 1,
              // Matches the 200-byte cap in the security rules.
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Write something…',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
