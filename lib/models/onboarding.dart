import 'dart:convert';

/// What the deep-link user types into the details form.
class LeadDetails {
  const LeadDetails({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });

  final String name;
  final String email;
  final String phone;
  final String address;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
      };

  static LeadDetails fromJson(Map<String, dynamic> json) => LeadDetails(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );
}

/// Where a user is in the deep-link flow.
///
/// [inactive] means no onboarding link has ever been opened on this device, and
/// the app behaves exactly as it did before this flow existed.
enum OnboardingStage { inactive, details, paywall, member }

class OnboardingState {
  const OnboardingState({
    this.stage = OnboardingStage.inactive,
    this.details,
    this.planId,
  });

  final OnboardingStage stage;

  /// Kept when the user goes back from the paywall, so the form is pre-filled.
  final LeadDetails? details;

  /// The plan bought on the paywall. Non-null only in [OnboardingStage.member].
  final String? planId;

  bool get isActive => stage != OnboardingStage.inactive;

  String encode() => jsonEncode(<String, Object?>{
        'stage': stage.name,
        'details': details?.toJson(),
        'planId': planId,
      });

  /// Anything unreadable decodes to the inactive state: a corrupt value must
  /// never lock a user out of the normal app.
  static OnboardingState decode(String? source) {
    if (source == null) return const OnboardingState();
    try {
      final Map<String, dynamic> json =
          jsonDecode(source) as Map<String, dynamic>;
      final Map<String, dynamic>? details =
          json['details'] as Map<String, dynamic>?;
      return OnboardingState(
        stage: OnboardingStage.values.byName(json['stage'] as String),
        details: details == null ? null : LeadDetails.fromJson(details),
        planId: json['planId'] as String?,
      );
    } catch (_) {
      return const OnboardingState();
    }
  }
}
