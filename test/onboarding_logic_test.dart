import 'dart:ui' show Color, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:evos/models/country.dart';
import 'package:evos/models/onboarding.dart';
import 'package:evos/models/remote_config.dart';
import 'package:evos/screens/onboarding/paywall_screen.dart';
import 'package:evos/services/deep_link_service.dart';
import 'package:evos/services/evos_backend.dart';
import 'package:evos/services/install_referrer_service.dart';
import 'package:evos/utils/validators.dart';

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
      expect(isOnboardingReferrer('flow%3D%E0%A4%A'), isFalse);
    });

    test('accepts the marker handed over still encoded', () {
      expect(isOnboardingReferrer('flow%3Donboarding'), isTrue);
      expect(
        isOnboardingReferrer('utm_source%3Dmail%26flow%3Donboarding'),
        isTrue,
      );
      expect(isOnboardingReferrer('flow%3Dother'), isFalse);
    });
  });

  group('isReferrerFinal', () {
    test('any answer with content settles it at once', () {
      expect(isReferrerFinal('flow=onboarding', 1), isTrue);
      expect(isReferrerFinal('utm_source=google-play&utm_medium=organic', 1),
          isTrue);
    });

    test('an empty answer is asked for again until the last attempt', () {
      for (int attempt = 1; attempt < kReferrerMaxAttempts; attempt++) {
        expect(isReferrerFinal('', attempt), isFalse);
        expect(isReferrerFinal('  ', attempt), isFalse);
      }
      expect(isReferrerFinal('', kReferrerMaxAttempts), isTrue);
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

    test('keeps the review-account flag', () {
      const OnboardingState review = OnboardingState(
        stage: OnboardingStage.web,
        reviewAccount: true,
      );
      expect(OnboardingState.decode(review.encode()).reviewAccount, isTrue);
      expect(
        OnboardingState.decode(
          const OnboardingState(stage: OnboardingStage.web).encode(),
        ).reviewAccount,
        isFalse,
      );
    });

    test('nothing stored means the mobile-number screen', () {
      expect(OnboardingState.decode(null).stage, OnboardingStage.signIn);
    });

    test('a corrupt or unknown value falls back to signing in', () {
      expect(OnboardingState.decode('not json').stage, OnboardingStage.signIn);
      expect(
        OnboardingState.decode('{"stage":"gone"}').stage,
        OnboardingStage.signIn,
      );
    });

    test('the maintenance stage of older builds is the web page', () {
      expect(
        OnboardingState.decode('{"stage":"maintenance"}').stage,
        OnboardingStage.web,
      );
    });

    test('a stage saved by the details-form build signs in again', () {
      for (final String old in <String>['inactive', 'details', 'member']) {
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

  group('other countries', () {
    const Country uk = Country('United Kingdom', 'GB', '44');

    test('a trunk 0 and a pasted country code are removed', () {
      expect(normalizeNationalNumber(uk, '07911 123456'), '7911123456');
      expect(normalizeNationalNumber(uk, '+44 7911 123456'), '7911123456');
    });

    test('too short or too long for any number is refused', () {
      expect(normalizeNationalNumber(uk, '12345'), isNull);
      // 13 national digits plus the 2 of +44 is 15, the limit.
      expect(normalizeNationalNumber(uk, '1234567890123'), isNotNull);
      expect(normalizeNationalNumber(uk, '12345678901234'), isNull);
      expect(validateNationalNumber(uk, ''), 'Enter your mobile number.');
    });

    test('India keeps its own strict rule', () {
      expect(normalizeNationalNumber(kIndia, '1234567890'), isNull);
      expect(normalizeNationalNumber(kIndia, '+91 98765 43210'), '9876543210');
    });

    test('flags come from the ISO code, and every code is unique', () {
      expect(kIndia.flag, '🇮🇳');
      final Set<String> codes = kCountries.map((Country c) => c.isoCode).toSet();
      expect(codes, hasLength(kCountries.length));
      expect(countryByIso('GB')?.dialCode, '44');
    });
  });

  group('RemoteConfig', () {
    test('no rows gives a complete default', () {
      final RemoteConfig config = RemoteConfig.fromRows(<String, String>{});
      expect(config.appName, 'Evos');
      expect(config.logoUrl, isNull);
      expect(config.previewVideoUrl, isNull);
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
        'paywall_video_url': 'https://cdn.example.com/preview.mp4',
        'theme_color': '#0B7A5C',
        'paywall_features': 'One | Two|| Three ',
        'paywall_social_proofs': 'A|B',
        'paywall_rating_value': '4.6',
        'cashfree_plan_id': 'zed_monthly',
        'cashfree_trial_amount': '5',
        'cashfree_recurring_amount': '499.50',
        'webview_url': 'https://app.example.com/home',
      });
      expect(config.appName, 'Zed');
      expect(config.logoUrl, 'https://cdn.example.com/logo.png');
      expect(config.previewVideoUrl, 'https://cdn.example.com/preview.mp4');
      expect(config.seedColor, const Color(0xFF0B7A5C));
      expect(config.features, <String>['One', 'Two', 'Three']);
      expect(config.socialProofs, <String>['A', 'B']);
      expect(config.ratingValue, '4.6');
      expect(config.analyticsPlanId, 'zed_monthly');
      expect(config.trialPriceLabel, '₹5');
      expect(config.recurringPriceLabel, '₹499.50');
      expect(config.webUrl, 'https://app.example.com/home');
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

    test('login slides pair images and titles by position', () {
      final List<LoginSlide> slides = RemoteConfig.fromRows(<String, String>{
        'login_slide_images': 'https://a.example/1.png|http://bad.example/2.png'
            '| https://a.example/3.png ',
        'login_slide_titles': 'One|Two',
      }).loginSlides;
      // The insecure image is dropped without moving "Two" onto the third.
      expect(slides.map((LoginSlide s) => s.imageUrl), <String>[
        'https://a.example/1.png',
        'https://a.example/3.png',
      ]);
      expect(slides.map((LoginSlide s) => s.title), <String>['One', '']);
      expect(RemoteConfig.fromRows(<String, String>{}).loginSlides, isEmpty);
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

  group('paywall settings', () {
    RemoteConfig read(Map<String, String> rows) => RemoteConfig.fromRows(rows);

    test('no rows keeps the paywall as it was', () {
      final RemoteConfig config = read(<String, String>{});
      expect(config.videoAspectRatio, 1);
      expect(config.paywallSubtitle, isEmpty);
      expect(config.featureIcon(0), isEmpty);
      expect(config.showStrikePrice, isTrue);
      expect(config.accentColor, isNull);
      expect(config.socialProofIcon, isEmpty);
      expect(config.ctaText, 'Try Now');
      expect(config.upiSelectText, 'Select UPI App');
      expect(config.upiSheetTitle, 'Pay with UPI AutoPay');
      expect(
        config.autoPayStatement,
        '₹3 today for the first 24 hours, then ₹299 every month by UPI '
        'AutoPay. Cancel any time in your UPI app.',
      );
    });

    test('reads the video shape in each form', () {
      expect(read(<String, String>{'paywall_video_aspect_ratio': '9:16'})
          .videoAspectRatio, 9 / 16);
      expect(read(<String, String>{'paywall_video_aspect_ratio': ' 16 / 9 '})
          .videoAspectRatio, 16 / 9);
      expect(read(<String, String>{'paywall_video_aspect_ratio': '0.8'})
          .videoAspectRatio, 0.8);
    });

    test('a nonsense video shape falls back to square', () {
      for (final String bad in <String>['wide', '1:0', '0', '1:10', '10:1']) {
        expect(
          read(<String, String>{'paywall_video_aspect_ratio': bad})
              .videoAspectRatio,
          1,
          reason: bad,
        );
      }
    });

    test('the backend words the AutoPay sentence, with the live prices', () {
      final RemoteConfig config = read(<String, String>{
        'cashfree_trial_amount': '5',
        'cashfree_recurring_amount': '499',
        'paywall_autopay_text': 'Pay {trial} now, then {recurring} a month.',
      });
      expect(config.autoPayStatement, 'Pay ₹5 now, then ₹499 a month.');
    });

    test('a blank AutoPay sentence falls back to the app\'s own', () {
      expect(
        read(<String, String>{'paywall_autopay_text': '  '}).autoPayStatement,
        startsWith('₹3 today for the first 24 hours'),
      );
    });

    test('feature icons are paired by position, blanks included', () {
      final RemoteConfig config = read(<String, String>{
        'paywall_feature_icons': 'lock||https://cdn.example.com/b.png',
      });
      expect(config.featureIcon(0), 'lock');
      expect(config.featureIcon(1), isEmpty);
      expect(config.featureIcon(2), 'https://cdn.example.com/b.png');
      expect(config.featureIcon(3), isEmpty);
    });

    test('blank texts fall back; colours and switches are checked', () {
      final RemoteConfig config = read(<String, String>{
        'paywall_cta_text': ' ',
        'paywall_upi_select_text': '',
        'paywall_accent_color': 'gold',
        'paywall_show_strike_price': 'maybe',
      });
      expect(config.ctaText, 'Try Now');
      expect(config.upiSelectText, 'Select UPI App');
      expect(config.accentColor, isNull);
      expect(config.showStrikePrice, isTrue);
      expect(
        read(<String, String>{
          'paywall_show_strike_price': 'false',
          'paywall_accent_color': '#E11D48',
        }).showStrikePrice,
        isFalse,
      );
    });
  });

  group('per-source identity overlay (mergeSourceRow)', () {
    Map<String, String> global() => <String, String>{
          'app_name': 'Evos',
          'theme_color': '#6D28D9',
          'webview_url': 'https://global.example.com',
        };

    test('a non-null column overrides the matching global key', () {
      final Map<String, String> config = global();
      SupabaseEvosBackend.mergeSourceRow(config, <String, dynamic>{
        'source': 'filmyface',
        'is_active': true,
        'app_name': 'FilmyFace',
        'theme_color': '#E11D48',
        'webview_url': 'https://filmyface.example.com',
      });
      expect(config['app_name'], 'FilmyFace');
      expect(config['theme_color'], '#E11D48');
      expect(config['webview_url'], 'https://filmyface.example.com');
      // And the whole config still reads as a branded RemoteConfig.
      final RemoteConfig brand = RemoteConfig.fromRows(config);
      expect(brand.appName, 'FilmyFace');
      expect(brand.seedColor, const Color(0xFFE11D48));
    });

    test('a null column inherits the global value', () {
      final Map<String, String> config = global();
      SupabaseEvosBackend.mergeSourceRow(config, <String, dynamic>{
        'source': 'partner',
        'is_active': true,
        'app_name': 'Partner',
        'theme_color': null, // inherit
        'webview_url': null, // inherit
      });
      expect(config['app_name'], 'Partner');
      expect(config['theme_color'], '#6D28D9');
      expect(config['webview_url'], 'https://global.example.com');
    });

    test('an empty string is a deliberate override, not an inherit', () {
      final Map<String, String> config = global()
        ..['paywall_subtitle'] = 'Global subtitle';
      SupabaseEvosBackend.mergeSourceRow(config, <String, dynamic>{
        'source': 'partner',
        'paywall_subtitle': '', // hide it for this source
      });
      expect(config['paywall_subtitle'], '');
    });

    test('meta columns and non-string values are handled', () {
      final Map<String, String> config = global();
      SupabaseEvosBackend.mergeSourceRow(config, <String, dynamic>{
        'source': 'partner',
        'is_active': true,
        'paywall_show_strike_price': false, // stringified
      });
      // source/is_active are not treated as settings.
      expect(config.containsKey('source'), isFalse);
      expect(config.containsKey('is_active'), isFalse);
      expect(config['paywall_show_strike_price'], 'false');
    });
  });

  group('previewCardSize', () {
    test('full width at the backend shape', () {
      expect(
        previewCardSize(maxWidth: 312, maxHeight: 360, ratio: 1),
        const Size(312, 312),
      );
    });

    test('a tall shape is narrowed to fit the height, whole', () {
      expect(
        previewCardSize(maxWidth: 312, maxHeight: 320, ratio: 9 / 16),
        const Size(180, 320),
      );
    });
  });
}
