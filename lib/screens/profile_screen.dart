import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/analytics.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/track_view.dart';
import '../widgets/user_avatar.dart';

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

    final String name = user.displayName?.trim().isNotEmpty ?? false
        ? user.displayName!.trim()
        : 'Signed in';

    return TrackView(
      onView: (Analytics analytics) => analytics.profileViewed(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            _Header(user: user, name: name),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Account',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // A row of plain texts rather than a ListTile, which would merge
            // them into one node; the Maestro flow looks for "User ID" alone.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('User ID', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            user.uid,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.4),
                ),
                minimumSize: const Size.fromHeight(56),
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
}

/// The violet card at the top, in the launcher icon's colours.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.name});

  final User user;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            top: -8,
            right: -4,
            child: CircleAvatar(radius: 6, backgroundColor: kBrandAmber),
          ),
          Column(
            children: <Widget>[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  child: UserAvatar(user: user, radius: 42),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              if (user.email != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  user.email!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
