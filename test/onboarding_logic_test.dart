import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:notes/models/onboarding.dart';
import 'package:notes/models/remote_config.dart';
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
    test('round-trips every stage', () {
      for (final OnboardingStage stage in OnboardingStage.values) {
        expect(
          OnboardingState.decode(OnboardingState(stage: stage).encode()).stage,
          stage,
        );
      }
    });

    test('nothing stored means the normal app', () {
      expect(OnboardingState.decode(null).isActive, isFalse);
    });

    test('a corrupt or unknown value falls back to the normal app', () {
      expect(OnboardingState.decode('not json').isActive, isFalse);
      expect(OnboardingState.decode('{"stage":"gone"}').isActive, isFalse);
    });

    test('a stage saved by the details-form build signs in again', () {
      for (final String old in <String>['details', 'member']) {
        expect(
          OnboardingState.decode('{"stage":"$old","planId":"yearly"}').stage,
          OnboardingStage.signIn,
        );
      }
    });
  });

  group('mobile number', () {
    test('accepts ten digits however they are typed', () {
      for (final String typed in <String>[
        '9876543210',
        '98765 43210',
        '98765-43210',
        '+91 98765 43210',
        '919876543210',
        '09876543210',
      ]) {
        expect(normalizeIndianMobile(typed), '9876543210', reason: typed);
        expect(validateIndianMobile(typed), isNull, reason: typed);
      }
    });

    test('rejects anything that is not an Indian mobile number', () {
      for (final String typed in <String>[
        '12345',
        '1234567890', // starts below 6: a landline or a typo
        '98765abc10',
        '987654321012',
        '+1 415 555 0100',
      ]) {
        expect(normalizeIndianMobile(typed), isNull, reason: typed);
        expect(validateIndianMobile(typed), isNotNull, reason: typed);
      }
    });

    test('an empty field asks for the number', () {
      expect(validateIndianMobile(''), 'Enter your mobile number.');
      expect(validateIndianMobile(null), 'Enter your mobile number.');
    });
  });

  group('RemoteConfig', () {
    test('no rows gives a complete default', () {
      final RemoteConfig config = RemoteConfig.fromRows(<String, String>{});
      expect(config.appName, 'Evos');
      expect(config.logoUrl, isNull);
      expect(config.trialPriceLabel, '₹3');
      expect(config.recurringPriceLabel, '₹299');
      expect(config.features, isNotEmpty);
      // Nothing the app could not stand behind is shown by default.
      expect(config.ratingValue, isEmpty);
      expect(config.socialProofs, isEmpty);
    });

    test('reads what the backend sends', () {
      final RemoteConfig config = RemoteConfig.fromRows(<String, String>{
        'app_name': 'Zed',
        'app_logo_url': 'https://cdn.example.com/logo.png',
        'theme_color': '#0B7A5C',
        'paywall_features': 'One | Two|| Three ',
        'paywall_social_proofs': 'A|B',
        'paywall_rating_value': '4.6',
        'cashfree_plan_id': 'zed_monthly',
        'cashfree_trial_amount': '5',
        'cashfree_recurring_amount': '499.50',
        'maintenance_title': 'Back soon',
      });
      expect(config.appName, 'Zed');
      expect(config.logoUrl, 'https://cdn.example.com/logo.png');
      expect(config.seedColor, const Color(0xFF0B7A5C));
      expect(config.features, <String>['One', 'Two', 'Three']);
      expect(config.socialProofs, <String>['A', 'B']);
      expect(config.ratingValue, '4.6');
      expect(config.analyticsPlanId, 'zed_monthly');
      expect(config.trialPriceLabel, '₹5');
      expect(config.recurringPriceLabel, '₹499.50');
      expect(config.maintenanceTitle, 'Back soon');
      // Follows the name when no plan name is sent.
      expect(config.planName, 'Zed Premium Monthly');
    });

    test('a bad value falls back instead of breaking the screen', () {
      final RemoteConfig config = RemoteConfig.fromRows(<String, String>{
        'app_name': '   ',
        'app_logo_url': 'http://insecure.example.com/logo.png',
        'theme_color': 'purple',
        'cashfree_trial_amount': '-3',
        'cashfree_recurring_amount': 'lots',
      });
      expect(config.appName, 'Evos');
      expect(config.logoUrl, isNull);
      expect(config.seedColor, const RemoteConfig().seedColor);
      expect(config.trialAmount, 3);
      expect(config.recurringAmount, 299);
    });

    test('a blank row hides an optional part; a missing row keeps the default',
        () {
      expect(
        RemoteConfig.fromRows(<String, String>{'paywall_features': ''}).features,
        isEmpty,
      );
      expect(
        RemoteConfig.fromRows(<String, String>{}).features,
        const RemoteConfig().features,
      );
    });

    test('at most four features are shown', () {
      expect(
        RemoteConfig.fromRows(<String, String>{
          'paywall_features': 'a|b|c|d|e|f',
        }).features,
        hasLength(4),
      );
    });

    test('saved rows survive a round trip, and junk reads as nothing', () {
      final Map<String, String> rows = <String, String>{'app_name': 'Zed'};
      expect(decodeConfigRows(encodeConfigRows(rows)), rows);
      expect(decodeConfigRows(null), isNull);
      expect(decodeConfigRows('not json'), isNull);
    });
  });
}
