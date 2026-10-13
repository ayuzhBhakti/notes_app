import 'dart:convert';

/// Where a user is in the deep-link flow.
///
/// [inactive] means no onboarding link has ever been opened on this device, and
/// the app behaves exactly as it did before this flow existed.
///
/// [signIn] covers both the mobile-number screen and the code screen; which of
/// the two is showing is not saved, because a code does not outlive a restart.
enum OnboardingStage { inactive, signIn, paywall, maintenance }

class OnboardingState {
  const OnboardingState({this.stage = OnboardingStage.inactive});

  final OnboardingStage stage;

  bool get isActive => stage != OnboardingStage.inactive;

  String encode() => jsonEncode(<String, Object?>{'stage': stage.name});

  /// Anything unreadable decodes to the inactive state: a corrupt value must
  /// never lock a user out of the normal app.
  static OnboardingState decode(String? source) {
    if (source == null) return const OnboardingState();
    try {
      final Map<String, dynamic> json =
          jsonDecode(source) as Map<String, dynamic>;
      final String name = json['stage'] as String;
      // Saved by the build that had a details form and a simulated purchase.
      // That device is still in the flow, but has no account, so it signs in.
      if (name == 'details' || name == 'member') {
        return const OnboardingState(stage: OnboardingStage.signIn);
      }
      return OnboardingState(stage: OnboardingStage.values.byName(name));
    } catch (_) {
      return const OnboardingState();
    }
  }
}
