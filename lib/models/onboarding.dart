import 'dart:convert';

/// Where a user is in the app: sign in, pay, then the web page — or, for the
/// store-review number, the local notes screen.
///
/// [signIn] covers both the mobile-number screen and the code screen; which of
/// the two is showing is not saved, because a code does not outlive a restart.
///
/// [notes] is only ever reached by the review account, which is why it always
/// carries [OnboardingState.reviewAccount]. Everyone else goes to [web].
enum OnboardingStage { signIn, paywall, web, notes }

class OnboardingState {
  const OnboardingState({
    this.stage = OnboardingStage.signIn,
    this.reviewAccount = false,
  });

  final OnboardingStage stage;

  /// Signed in with the store-review number (see `review_account.dart`). Such
  /// a device has no Supabase session and is never asked about a
  /// subscription, so nothing on the server can move it off the web page.
  final bool reviewAccount;

  String encode() => jsonEncode(<String, Object?>{
        'stage': stage.name,
        if (reviewAccount) 'review': true,
      });

  /// Anything unreadable decodes to the mobile-number screen: signing in again
  /// is always safe, and the server then says where the user belongs.
  static OnboardingState decode(String? source) {
    if (source == null) return const OnboardingState();
    try {
      final Map<String, dynamic> json =
          jsonDecode(source) as Map<String, dynamic>;
      final String name = json['stage'] as String;
      final bool review = json['review'] == true;
      return switch (name) {
        // Saved by builds that had a maintenance screen where the web page
        // now is.
        'maintenance' => OnboardingState(
            stage: OnboardingStage.web,
            reviewAccount: review,
          ),
        // `inactive` was the notes app, `details` and `member` a build with a
        // details form. None of them has a phone sign-in.
        'inactive' || 'details' || 'member' => const OnboardingState(),
        _ => OnboardingState(
            stage: OnboardingStage.values.byName(name),
            reviewAccount: review,
          ),
      };
    } catch (_) {
      return const OnboardingState();
    }
  }
}
