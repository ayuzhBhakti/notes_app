import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// The signed-in user's Google photo, or their initials while it loads or
/// when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final User user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? photoUrl = user.photoURL;
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
      child: Text(
        _initials(user.displayName ?? user.email ?? ''),
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: radius * 0.75,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
