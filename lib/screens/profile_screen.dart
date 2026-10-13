import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/analytics.dart';
import '../utils/errors.dart';
import '../widgets/track_view.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(currentUserProvider);
    final ThemeData theme = Theme.of(context);
    final bool busy = ref.watch(signInControllerProvider).isLoading;

    // Signing out pops this route via the auth gate, but the frame in between
    // still builds, so handle the null case rather than asserting on it.
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String? photoUrl = user.photoURL;
    final String name = user.displayName?.trim().isNotEmpty ?? false
        ? user.displayName!.trim()
        : 'Signed in';

    return TrackView(
      onView: (Analytics analytics) => analytics.profileViewed(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: <Widget>[
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundImage:
                    photoUrl == null ? null : NetworkImage(photoUrl),
                child: Text(
                  _initials(name),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(name, style: theme.textTheme.titleLarge),
            ),
            if (user.email != null) ...<Widget>[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.email!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('User ID'),
              subtitle: Text(user.uid),
            ),
            const Divider(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _confirmSignOut(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text(
              'Your notes stay in your account and will be here when you '
              'sign back in.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await ref.read(signInControllerProvider.notifier).signOut();

    final Object? error = ref.read(signInControllerProvider).error;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error).message)),
      );
    }
    // On success the auth gate swaps in the sign-in screen; no pop needed here.
  }

  String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
