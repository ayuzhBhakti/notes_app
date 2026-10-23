import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../providers.dart';
import '../services/analytics.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/note_tile.dart';
import '../widgets/track_view.dart';
import 'note_editor_screen.dart';
import 'profile_screen.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Note>> notes = ref.watch(localNotesStreamProvider);

    return TrackView(
      onView: (Analytics analytics) => analytics.notesListViewed(),
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context, null),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('New note'),
        ),
        body: CustomScrollView(
          slivers: <Widget>[
            // One row: the big "Notes" title level with the avatar, pinned,
            // so the list starts right under it.
            SliverAppBar(
              pinned: true,
              toolbarHeight: 72,
              titleSpacing: 20,
              title: Text(
                'Notes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              actions: <Widget>[
                // Selected by the Maestro flows in .maestro/; a tooltip alone
                // is not exposed as text on Android 9+.
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
                const SizedBox(width: 8),
              ],
            ),
            ...notes.when(
              // Without this, signing in (or any auth re-emit) blanks the list
              // and flashes a spinner over content that is already correct.
              skipLoadingOnReload: true,
              loading: () => <Widget>[
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (Object error, StackTrace _) => <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorView(
                    failure: describeError(error),
                    onRetry: () => ref.invalidate(localNotesStreamProvider),
                  ),
                ),
              ],
              data: (List<Note> items) {
                if (items.isEmpty) {
                  return <Widget>[
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyView(),
                    ),
                  ];
                }
                return <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        items.length == 1 ? '1 note' : '${items.length} notes',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    // Room at the bottom so the last card clears the button.
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) =>
                          _row(context, ref, items[index]),
                    ),
                  ),
                ];
              },
            ),
          ],
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
        padding: const EdgeInsets.only(right: 28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          // The card's radius, so the red shows the card's shape.
          borderRadius: BorderRadius.circular(20),
        ),
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
    final LocalNoteActions actions = ref.read(localNoteActionsProvider.notifier);

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
                  ref.read(localNoteActionsProvider).error ?? 'Delete failed',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const _Badge(icon: Icons.sticky_note_2_outlined),
          const SizedBox(height: 28),
          Text('No notes yet', style: theme.textTheme.titleLarge),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const _Badge(icon: Icons.cloud_off_outlined, error: true),
          const SizedBox(height: 28),
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
    );
  }
}

/// A large icon on a soft circle, with the icon's amber dot, for the empty
/// and error states.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.error = false});

  final IconData icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (error ? colors.error : colors.primary)
                  .withValues(alpha: 0.10),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 52,
                color: error ? colors.error : colors.primary,
              ),
            ),
          ),
          if (!error)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBrandAmber,
                  border: Border.all(color: colors.surface, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
