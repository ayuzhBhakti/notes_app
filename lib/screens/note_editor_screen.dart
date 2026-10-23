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
  void initState() {
    super.initState();
    ref.read(analyticsProvider).noteEditorOpened(isNew: widget.note == null);
  }

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
    final LocalNoteActions actions = ref.read(localNoteActionsProvider.notifier);

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
                ref.read(localNoteActionsProvider).error ?? 'Save failed',
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
    final LocalNoteActions actions = ref.read(localNoteActionsProvider.notifier);

    unawaited(
      actions.delete(note.id).then((bool ok) {
        messenger.clearSnackBars();
        if (!ok) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                describeError(
                  ref.read(localNoteActionsProvider).error ?? 'Delete failed',
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
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit note' : 'New note',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: <Widget>[
          // The Semantics identifiers in this screen are what the Maestro flows
          // in .maestro/ select on. A tooltip is not exposed as text on
          // Android 9+, and a hint disappears once the field has content, so
          // neither is a stable selector.
          if (isEditing)
            Semantics(
              identifier: 'note_delete_button',
              child: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ),
          Semantics(
            identifier: 'note_save_button',
            child: IconButton.filled(
              tooltip: 'Save',
              icon: const Icon(Icons.check_rounded),
              onPressed: _save,
              // The app bar's icon colour would otherwise win over the
              // filled button's and draw a dark tick on the violet.
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              identifier: 'note_title_field',
              child: TextField(
                controller: _title,
                maxLines: 1,
                // Matches the 200-byte cap in the security rules.
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.headlineSmall,
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // A short violet rule under the title, after the icon's style.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Semantics(
                identifier: 'note_body_field',
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Write something…',
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
