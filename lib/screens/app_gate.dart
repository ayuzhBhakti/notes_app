import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding.dart';
import '../providers.dart';
import 'auth_gate.dart';
import 'onboarding/details_form_screen.dart';
import 'onboarding/member_home_screen.dart';
import 'onboarding/paywall_screen.dart';

/// The root of the app. Chooses between the normal notes app and the
/// interface for users who arrived through an onboarding deep link.
///
/// The onboarding stages are swapped here rather than pushed as routes, the
/// same way [AuthGate] swaps sign-in for the notes list, so the stage and the
/// screen can never disagree.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<OnboardingStage>(
      onboardingControllerProvider.select((OnboardingState s) => s.stage),
      (OnboardingStage? previous, OnboardingStage next) {
        // A link can arrive while a note editor or the profile is open.
        // Swapping the root does not remove routes pushed above it, so they
        // have to be popped or they would keep covering the form.
        if (previous == OnboardingStage.inactive &&
            next != OnboardingStage.inactive) {
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        }
      },
    );

    final OnboardingStage stage = ref.watch(
      onboardingControllerProvider.select((OnboardingState s) => s.stage),
    );

    return switch (stage) {
      OnboardingStage.inactive => const AuthGate(),
      OnboardingStage.details => const DetailsFormScreen(),
      OnboardingStage.paywall => const PaywallScreen(),
      OnboardingStage.member => const MemberHomeScreen(),
    };
  }
}
