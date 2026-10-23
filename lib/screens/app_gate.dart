import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding.dart';
import '../providers.dart';
import '../widgets/brand.dart';
import 'notes_list_screen.dart';
import 'onboarding/otp_screen.dart';
import 'onboarding/paywall_screen.dart';
import 'onboarding/phone_screen.dart';
import 'onboarding/web_screen.dart';

/// The root of the app: mobile number, code, paywall, then the web page — or
/// the local notes screen for the store-review account.
///
/// The stages are swapped here rather than pushed as routes, so the stage and
/// the screen can never disagree.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<OnboardingStage>(
      onboardingControllerProvider.select((OnboardingState s) => s.stage),
      (OnboardingStage? previous, OnboardingStage next) {
        // A stage can change under an open sheet. Swapping the root does not
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

    // The notes screen (review account) keeps the app's own violet theme from
    // the root MaterialApp; it is not a backend-branded screen.
    if (stage == OnboardingStage.notes) return const NotesListScreen();

    // The backend's name and colour apply to the sign-in, paywall and web page.
    return BrandShell(
      child: switch (stage) {
        OnboardingStage.signIn => const _SignIn(),
        OnboardingStage.paywall => const PaywallScreen(),
        OnboardingStage.web => const WebScreen(),
        OnboardingStage.notes => const NotesListScreen(),
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
