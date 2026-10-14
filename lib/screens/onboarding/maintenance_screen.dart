import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/onboarding.dart';
import '../../models/remote_config.dart';
import '../../providers.dart';
import '../../services/analytics.dart';
import '../../widgets/brand.dart';
import '../../widgets/track_view.dart';

/// Where a subscriber lands: the app behind the paywall is not open yet.
///
/// The heading and message come from the backend, so what is said here can
/// change without an app update.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    final RemoteConfig before = ref.read(remoteConfigProvider);
    await ref.read(onboardingControllerProvider.notifier).refresh();
    // The refresh can move the device to another screen, which removes this one.
    if (!mounted) return;
    setState(() => _checking = false);
    final RemoteConfig after = ref.read(remoteConfigProvider);
    final bool unchanged = before.maintenanceTitle == after.maintenanceTitle &&
        before.maintenanceMessage == after.maintenanceMessage &&
        ref.read(onboardingControllerProvider).stage ==
            OnboardingStage.maintenance;
    if (unchanged) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nothing new yet. Check back later.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final RemoteConfig config = ref.watch(remoteConfigProvider);

    return TrackView(
      onView: (Analytics analytics) => analytics.maintenanceViewed(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandHeader(),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(34),
                              child: Icon(
                                Icons.construction_rounded,
                                size: 64,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            config.maintenanceTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            config.maintenanceMessage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Semantics(
                  identifier: 'maintenance_check_again_button',
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.tonal(
                      onPressed: _checking ? null : _checkAgain,
                      child: _checking
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Check again'),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  identifier: 'maintenance_logout_button',
                  child: TextButton(
                    onPressed: _checking
                        ? null
                        : () => ref
                            .read(onboardingControllerProvider.notifier)
                            .signOut(),
                    child: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
