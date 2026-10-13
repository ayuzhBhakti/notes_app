import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../providers.dart';
import '../services/analytics.dart';
import '../utils/errors.dart';
import '../widgets/note_tile.dart';
import '../widgets/track_view.dart';
import 'note_editor_screen.dart';
import 'profile_screen.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Note>> notes = ref.watch(notesStreamProvider);

    return TrackView(
      onView: (Analytics analytics) => analytics.notesListViewed(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notes'),
          actions: <Widget>[
            // Selected by the Maestro flows in .maestro/; a tooltip alone is not
            // exposed as text on Android 9+.
            Semantics(
              identifier: 'notes_profile_button',
              child: IconButton(
                tooltip: 'Profile',
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context, null),
          icon: const Icon(Icons.add),
          label: const Text('New note'),
        ),
        body: notes.when(
          // Without this, signing in (or any auth re-emit) blanks the list and
          // flashes a spinner over content that is already correct.
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => _ErrorView(
            failure: describeError(error),
            onRetry: () => ref.invalidate(notesStreamProvider),
          ),
          data: (List<Note> items) {
            if (items.isEmpty) return const _EmptyView();
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) =>
                  _row(context, ref, items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Note note) {
    return Dismissible(
      key: ValueKey<String>(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      // confirmDismiss, always returning false, rather than onDismissed.
      // Dismissible must never remove the row itself — the Firestore stream
      // does that within a frame, from the offline cache. Returning true and
      // then having the delete fail (permission-denied) would bring the
      // document straight back and Flutter would assert "A dismissed
      // Dismissible widget is still part of the tree."
      confirmDismiss: (DismissDirection _) async {
        _deleteWithUndo(context, ref, note);
        return false;
      },
      child: NoteTile(note: note, onTap: () => _openEditor(context, note)),
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref, Note note) {
    // Captured before any async gap: `context` may be defunct afterwards.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NoteActions actions = ref.read(noteActionsProvider.notifier);

    // Not awaited. Firestore commits to the local cache immediately, so the row
    // disappears within a frame, but the returned future does not complete
    // until the server acknowledges — which offline means not until reconnect.
    // Awaiting would leave the undo snackbar unshown for the entire time.
    unawaited(
      actions.delete(note.id).then((bool ok) {
        if (ok) return;
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                describeError(
                  ref.read(noteActionsProvider).error ?? 'Delete failed',
                ).message,
              ),
            ),
          );
      }),
    );

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${note.displayTitle}"'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            // `note` was captured before the delete, so undo still works once
            // the row is gone.
            onPressed: () => unawaited(actions.restore(note)),
          ),
        ),
      );
  }

  void _openEditor(BuildContext context, Note? note) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(note: note),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No notes yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap New note to write your first one.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (failure.hint != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                failure.hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
