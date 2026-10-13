import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding.dart';
import '../providers.dart';
import '../widgets/brand.dart';
import 'auth_gate.dart';
import 'onboarding/maintenance_screen.dart';
import 'onboarding/otp_screen.dart';
import 'onboarding/paywall_screen.dart';
import 'onboarding/phone_screen.dart';

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
        // A link can arrive while a note editor or the profile is open, and
        // a stage can change under an open sheet. Swapping the root does not
        // remove routes pushed above it, so they have to be popped or they
        // would keep covering the new screen.
        if (previous != next) {
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        }
      },
    );

    final OnboardingStage stage = ref.watch(
      onboardingControllerProvider.select((OnboardingState s) => s.stage),
    );
    if (stage == OnboardingStage.inactive) return const AuthGate();

    // The backend's name and colour apply from here down, and only here.
    return BrandShell(
      child: switch (stage) {
        OnboardingStage.inactive => const AuthGate(),
        OnboardingStage.signIn => const _SignIn(),
        OnboardingStage.paywall => const PaywallScreen(),
        OnboardingStage.maintenance => const MaintenanceScreen(),
      },
    );
  }
}

/// The mobile-number screen until a code has been sent, then the code screen.
class _SignIn extends ConsumerWidget {
  const _SignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool codeSent = ref.watch(
      phoneAuthControllerProvider.select((PhoneAuthState s) => s.phone != null),
    );
    return codeSent ? const OtpScreen() : const PhoneScreen();
  }
}
