import 'package:flutter_test/flutter_test.dart';
import 'package:notes/models/onboarding.dart';
import 'package:notes/services/deep_link_service.dart';
import 'package:notes/services/install_referrer_service.dart';
import 'package:notes/utils/validators.dart';

void main() {
  group('isOnboardingLink', () {
    test('accepts the full HTTPS link', () {
      expect(
        isOnboardingLink(Uri.parse('https://$kDeepLinkHost/onboarding')),
        isTrue,
      );
    });

    test('accepts a query string and a sub-path', () {
      expect(
        isOnboardingLink(
          Uri.parse('https://$kDeepLinkHost/onboarding/promo?ref=mail'),
        ),
        isTrue,
      );
    });

    test('accepts a path delivered without its origin', () {
      expect(isOnboardingLink(Uri.parse('/onboarding')), isTrue);
    });

    test('accepts the local test link, and only its onboarding host', () {
      expect(isOnboardingLink(Uri.parse('notes://onboarding')), isTrue);
      expect(isOnboardingLink(Uri.parse('notes://other')), isFalse);
      expect(isOnboardingLink(Uri.parse('notes:///onboarding')), isFalse);
    });

    test('rejects another host', () {
      expect(
        isOnboardingLink(Uri.parse('https://evil.example/onboarding')),
        isFalse,
      );
    });

    test('rejects another path, including one that only shares a prefix', () {
      expect(isOnboardingLink(Uri.parse('https://$kDeepLinkHost/')), isFalse);
      expect(
        isOnboardingLink(Uri.parse('https://$kDeepLinkHost/onboardingx')),
        isFalse,
      );
    });
  });

  group('isOnboardingReferrer', () {
    test('accepts the flow marker alone or among campaign parameters', () {
      expect(isOnboardingReferrer('flow=onboarding'), isTrue);
      expect(
        isOnboardingReferrer('utm_source=mail&flow=onboarding&utm_medium=x'),
        isTrue,
      );
    });

    test('rejects an organic install, another flow, and nothing at all', () {
      expect(
        isOnboardingReferrer('utm_source=google-play&utm_medium=organic'),
        isFalse,
      );
      expect(isOnboardingReferrer('flow=other'), isFalse);
      expect(isOnboardingReferrer('onboarding'), isFalse);
      expect(isOnboardingReferrer(''), isFalse);
      expect(isOnboardingReferrer(null), isFalse);
    });

    test('survives malformed percent encoding', () {
      expect(isOnboardingReferrer('flow=%E0%A4%A'), isFalse);
    });
  });

  group('OnboardingState persistence', () {
    test('round-trips every field', () {
      const OnboardingState state = OnboardingState(
        stage: OnboardingStage.member,
        details: LeadDetails(
          name: 'Asha Rao',
          email: 'asha@example.com',
          phone: '+91 98765 43210',
          address: '12 MG Road, Bengaluru',
        ),
        planId: 'yearly',
      );

      final OnboardingState decoded = OnboardingState.decode(state.encode());

      expect(decoded.stage, OnboardingStage.member);
      expect(decoded.planId, 'yearly');
      expect(decoded.details!.name, 'Asha Rao');
      expect(decoded.details!.email, 'asha@example.com');
      expect(decoded.details!.phone, '+91 98765 43210');
      expect(decoded.details!.address, '12 MG Road, Bengaluru');
    });

    test('nothing stored means the normal app', () {
      expect(OnboardingState.decode(null).isActive, isFalse);
    });

    test('a corrupt or unknown value falls back to the normal app', () {
      expect(OnboardingState.decode('not json').isActive, isFalse);
      expect(OnboardingState.decode('{"stage":"gone"}').isActive, isFalse);
    });
  });

  group('validators', () {
    test('name', () {
      expect(validateName(''), isNotNull);
      expect(validateName('  A '), isNotNull);
      expect(validateName('Asha Rao'), isNull);
    });

    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('asha'), isNotNull);
      expect(validateEmail('asha@example'), isNotNull);
      expect(validateEmail('asha @example.com'), isNotNull);
      expect(validateEmail(' asha@example.com '), isNull);
    });

    test('phone', () {
      expect(validatePhone(''), isNotNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone('98765abc10'), isNotNull);
      expect(validatePhone('9876543210'), isNull);
      expect(validatePhone('+91 98765-43210'), isNull);
      expect(validatePhone('(080) 2345 6789'), isNull);
    });

    test('address', () {
      expect(validateAddress(''), isNotNull);
      expect(validateAddress('12'), isNotNull);
      expect(validateAddress('12 MG Road'), isNull);
    });

    test('values longer than the Supabase columns allow are rejected', () {
      expect(validateName('a' * 200), isNull);
      expect(validateName('a' * 201), isNotNull);
      expect(validateEmail('${'a' * 320}@example.com'), isNotNull);
      expect(validatePhone('9876543210${' ' * 30}1'), isNotNull);
      expect(validateAddress('a' * 1000), isNull);
      expect(validateAddress('a' * 1001), isNotNull);
    });
  });
}
