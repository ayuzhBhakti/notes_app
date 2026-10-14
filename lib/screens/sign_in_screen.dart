import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/analytics.dart';
import '../utils/errors.dart';
import '../widgets/evos_mark.dart';
import '../widgets/track_view.dart';

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

    return TrackView(
      onView: (Analytics analytics) => analytics.signInViewed(),
      child: Scaffold(
        body: DecoratedBox(
          // A soft violet glow behind the logo, fading into the page.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.2),
              radius: 1.1,
              // Both stops opaque: a gradient from a translucent colour to an
              // opaque one blends the full-strength violet through the middle.
              colors: <Color>[
                Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  theme.colorScheme.surface,
                ),
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    // Fills the screen so the button sits at the bottom, and
                    // still scrolls when a banner or large text overflows it.
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: <Widget>[
                          const Spacer(),
                          const SizedBox(height: 32),
                          const EvosMark(size: 96),
                          const SizedBox(height: 28),
                          Text(
                            'Evos',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to keep your notes in sync.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 36),
                          const _Feature(
                            icon: Icons.cloud_done_outlined,
                            text: 'Saved to your Google account',
                          ),
                          const _Feature(
                            icon: Icons.devices_outlined,
                            text: 'The same notes on every phone you sign in on',
                          ),
                          const _Feature(
                            icon: Icons.wifi_off_rounded,
                            text: 'Keeps working when you are offline',
                          ),
                          const Spacer(),
                          const SizedBox(height: 32),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                busy ? 'Signing in…' : 'Continue with Google',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                            ),
                          ),
                          if (failure != null) ...<Widget>[
                            const SizedBox(height: 16),
                            _Banner(
                              icon: Icons.error_outline,
                              color: theme.colorScheme.error,
                              title: failure.message,
                              detail: failure.hint,
                            ),
                          ],
                          // The one failure mode with no diagnostic signal: an
                          // unregistered SHA-1 makes Credential Manager report
                          // a cancellation indistinguishable from a real one.
                          if (suspectMisconfiguration) ...<Widget>[
                            const SizedBox(height: 16),
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
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of what the app does, under the tagline.
class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
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
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
