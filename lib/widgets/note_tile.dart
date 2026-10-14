import 'package:flutter/material.dart';

import '../models/note.dart';
import '../utils/format.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String preview = note.body.trim().replaceAll('\n', ' ');
    final bool saving = note.updatedAt == null;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The tappable InkWell would otherwise merge every text in the
              // card into one semantics node ("title\nbody\ntime"), and the
              // Maestro flows look for the title and the body on their own.
              // Full width, so a flow's swipe from the title starts mid-card
              // and travels far enough to dismiss it.
              Semantics(
                container: true,
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    note.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              if (preview.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Semantics(
                  container: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    saving
                        ? Icons.cloud_upload_outlined
                        : Icons.schedule_rounded,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    // Renders "Saving…" while the server timestamp is
                    // unresolved. No spinner: Firestore's offline cache has
                    // already made the write durable, so there is nothing for
                    // the user to wait on.
                    formatNoteTime(note.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
