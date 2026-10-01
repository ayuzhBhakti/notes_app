import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../utils/errors.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SignInState> signIn = ref.watch(signInControllerProvider);
    final ThemeData theme = Theme.of(context);
    final bool busy = signIn.isLoading;

    // A cancel is not an error, so it is stored as data, not as an error state.
    final AppFailure? failure =
        signIn.hasError ? describeError(signIn.error!) : null;
    final bool suspectMisconfiguration =
        signIn.value?.suspectMisconfiguration ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text('Notes', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Sign in to keep your notes in sync.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => ref
                            .read(signInControllerProvider.notifier)
                            .signIn(),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      busy ? 'Signing in…' : 'Continue with Google',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                if (failure != null) ...<Widget>[
                  const SizedBox(height: 24),
                  _Banner(
                    icon: Icons.error_outline,
                    color: theme.colorScheme.error,
                    title: failure.message,
                    detail: failure.hint,
                  ),
                ],
                // The one failure mode with no diagnostic signal: an
                // unregistered SHA-1 makes Credential Manager report a
                // cancellation indistinguishable from a real one.
                if (suspectMisconfiguration) ...<Widget>[
                  const SizedBox(height: 24),
                  _Banner(
                    icon: Icons.help_outline,
                    color: theme.colorScheme.tertiary,
                    title: 'Sign-in keeps getting dismissed',
                    detail:
                        'If you did not cancel it yourself, this app’s '
                        'signing certificate is probably not registered in '
                        'Firebase. Add the debug SHA-1 fingerprint to the '
                        'Android app in Project settings, then try again.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.bodyMedium),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
