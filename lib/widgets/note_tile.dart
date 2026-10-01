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

    return ListTile(
      onTap: onTap,
      title: Text(
        note.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (preview.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text(
            // Renders "Saving…" while the server timestamp is unresolved. No
            // spinner: Firestore's offline cache has already made the write
            // durable, so there is nothing for the user to wait on.
            formatNoteTime(note.updatedAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      isThreeLine: preview.isNotEmpty,
    );
  }
}
