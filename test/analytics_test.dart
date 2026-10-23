import 'package:flutter_test/flutter_test.dart';
import 'package:evos/models/install_source.dart';
import 'package:evos/services/analytics.dart';
import 'package:evos/services/evos_backend.dart';
import 'package:evos/services/payment_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  group('InstallSource.parse', () {
    test('no referrer is an organic install from an unknown source', () {
      for (final String? referrer in <String?>[null, '', '   ']) {
        expect(InstallSource.parse(referrer).toProperties(), <String, Object>{
          'install_source': 'unknown',
          'install_medium': 'organic',
          'install_organic': true,
        });
      }
    });

    test("Play's own store-search referrer is organic", () {
      final InstallSource source =
          InstallSource.parse('utm_source=google-play&utm_medium=organic');
      expect(source.source, 'google-play');
      expect(source.isOrganic, isTrue);
    });

    test('a link that names only its source is still a link', () {
      final InstallSource source = InstallSource.parse(
        'utm_source=whatsapp&utm_campaign=diwali&flow=onboarding',
      );
      expect(source.toProperties(), <String, Object>{
        'install_source': 'whatsapp',
        'install_medium': 'link',
        'install_organic': false,
        'install_campaign': 'diwali',
      });
    });

    test('a Google Ads click is paid, and the click id is not kept', () {
      final InstallSource source = InstallSource.parse('gclid=abc123');
      expect(source.toProperties(), <String, Object>{
        'install_source': 'google-ads',
        'install_medium': 'cpc',
        'install_organic': false,
      });
    });

    test('reads a referrer handed over still encoded', () {
      final InstallSource source = InstallSource.parse(
        'utm_source%3Dmail%26utm_medium%3Dnewsletter%26utm_term%3Da%2520b',
      );
      expect(source.source, 'mail');
      expect(source.medium, 'newsletter');
      expect(source.term, 'a b');
    });

    test('drops unset values and survives junk', () {
      final InstallSource source = InstallSource.parse(
        'utm_source=mail&utm_campaign=(not set)&utm_content=%E0%A4%A&=x&novalue',
      );
      expect(source.campaign, isNull);
      // Malformed percent-encoding is kept as typed, not thrown on.
      expect(source.content, '%E0%A4%A');
    });

    test('cuts an over-long value', () {
      final InstallSource source =
          InstallSource.parse('utm_source=${'x' * 300}');
      expect(source.source.length, 100);
    });
  });

  group('Analytics', () {
    test('a simulated purchase is never reported to Meta as revenue', () {
      final Recorder recorder = Recorder();
      Analytics(recorder).subscriptionSucceeded(
        planId: 'yearly',
        amount: 1499,
        currency: 'INR',
        simulated: true,
      );

      expect(recorder.events, <String>['Subscription Succeeded']);
      expect(recorder.properties('Subscription Succeeded')['simulated'], true);
      expect(recorder.otherMethods, isEmpty);
    });

    test('a real purchase is reported to Meta', () {
      final Recorder recorder = Recorder();
      Analytics(recorder).subscriptionSucceeded(
        planId: 'yearly',
        amount: 1499,
        currency: 'INR',
        simulated: false,
      );

      expect(recorder.otherMethods, <String>['metaSubscribe']);
      expect(recorder.calls.last.$2, <String, Object?>{
        'plan_id': 'yearly',
        'amount': 1499.0,
        'currency': 'INR',
      });
    });

    test('the review account is neither identified nor a registration', () {
      final Recorder recorder = Recorder();
      Analytics(recorder).reviewAccountSignedIn();
      expect(recorder.events, <String>['Review Account Signed In']);
      expect(recorder.otherMethods, isEmpty);
    });

    test('a verified code identifies by account id, and only a new account '
        'is a registration for Meta', () {
      final Recorder returning = Recorder();
      Analytics(returning).otpVerified(userId: 'user-1', newUser: false);
      expect(returning.otherMethods, <String>['identify']);
      expect(returning.calls.first.$2, <String, Object?>{'id': 'user-1'});

      final Recorder first = Recorder();
      Analytics(first).otpVerified(userId: 'user-2', newUser: true);
      expect(first.otherMethods, <String>[
        'identify',
        'metaCompleteRegistration',
      ]);
    });

    test('sign-out is tracked before the reset', () {
      final Recorder recorder = Recorder();
      Analytics(recorder).signedOut();
      expect(
        recorder.calls.map(((String, Map<String, Object?>) c) => c.$1),
        <String>['track', 'reset'],
      );
    });

    test('an install source is stored and reported', () {
      final Recorder recorder = Recorder();
      Analytics(recorder).installAttributed(
        InstallSource.parse('utm_source=mail'),
        referrer: 'utm_source=mail',
        clickRecorded: true,
        attempt: 1,
      );
      expect(recorder.otherMethods, <String>['setInstallSource']);
      final Map<String, Object?> properties =
          recorder.properties('Install Attributed');
      expect(properties['install_source'], 'mail');
      expect(properties['install_referrer_raw'], 'utm_source=mail');
      expect(properties['referrer_click_recorded'], true);
      expect(properties['referrer_attempt'], 1);
    });

    test('the raw referrer is cut to 100 characters', () {
      final Recorder recorder = Recorder();
      final String long = 'utm_source=${'x' * 300}';
      Analytics(recorder).installAttributed(
        InstallSource.parse(long),
        referrer: long,
        clickRecorded: false,
        attempt: 2,
      );
      expect(
        (recorder.properties('Install Attributed')['install_referrer_raw']!
                as String)
            .length,
        100,
      );
    });
  });

  group('events sent by the app', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    testWidgets('an ordinary launch reports the mobile-number screen only',
        (tester) async {
      final Harness h = await launch(tester);
      expect(h.recorder.events, <String>['Phone Entry Viewed']);
    });

    testWidgets('the whole onboarding funnel, in order', (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.newUser = true,
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(h.recorder.events, <String>[
        'Deep Link Opened',
        'Phone Entry Viewed',
        'OTP Requested',
        'OTP Verified',
        'Paywall Viewed',
        'Checkout Started',
        'Subscription Succeeded',
        'Web Page Viewed',
      ]);
      expect(h.recorder.properties('Deep Link Opened'), <String, Object?>{
        'target': 'onboarding',
        'after_install': false,
      });
      expect(h.recorder.properties('Web Page Viewed'), <String, Object?>{
        'has_url': false,
      });
      expect(h.recorder.properties('OTP Requested'), <String, Object?>{
        'resend': false,
        'country': 'IN',
      });
      expect(h.recorder.properties('Checkout Started'), <String, Object?>{
        'plan_id': 'monthly',
        'upi_app': 'PhonePe',
      });
      // What was authorised today: the trial price, not the monthly one.
      expect(h.recorder.properties('Subscription Succeeded'), <String, Object?>{
        'plan_id': 'monthly',
        'amount': 3.0,
        'currency': 'INR',
        'simulated': false,
      });
      expect(h.recorder.otherMethods, <String>[
        'identify',
        'metaCompleteRegistration',
        'metaInitiateCheckout',
        'metaSubscribe',
      ]);
    });

    testWidgets('a simulated payment reaches Mixpanel but never Meta',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(isSimulated: true),
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(
        h.recorder.properties('Subscription Succeeded')['simulated'],
        true,
      );
      expect(h.recorder.otherMethods, isNot(contains('metaSubscribe')));
    });

    testWidgets('the backend plan id and price are what is reported',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.config = <String, String>{
          'cashfree_plan_id': 'evos_monthly',
          'cashfree_trial_amount': '5',
        },
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(h.recorder.properties('Subscription Succeeded'), <String, Object?>{
        'plan_id': 'evos_monthly',
        'amount': 5.0,
        'currency': 'INR',
        'simulated': false,
      });
    });

    testWidgets('neither the mobile number nor the code is sent',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await sendCode(tester);
      await enterCode(tester, '000000');
      await enterCode(tester);
      await tapTryNow(tester);

      final String everything = h.recorder.calls.toString();
      for (final String typed in <String>[phone, '98765', '000000', rightCode]) {
        expect(everything, isNot(contains(typed)));
      }
    });

    testWidgets('a failed send is reported with a reason, not a message',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.sendError = BackendError.tooManyRequests,
      );
      await sendCode(tester);

      expect(h.recorder.events.last, 'OTP Request Failed');
      expect(h.recorder.properties('OTP Request Failed'), <String, Object?>{
        'reason': 'tooManyRequests',
      });
    });

    testWidgets('a wrong code is reported, and a resend says it is one',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await sendCode(tester);
      await enterCode(tester, '000000');

      expect(h.recorder.properties('OTP Verify Failed'), <String, Object?>{
        'reason': 'wrongCode',
      });
      expect(h.recorder.events, isNot(contains('OTP Verified')));

      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();

      expect(h.recorder.events.last, 'OTP Requested');
      expect(h.recorder.calls.last.$2['properties'], <String, Object?>{
        'resend': true,
        'country': 'IN',
      });
    });

    testWidgets('choosing a UPI app is reported by its name', (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);
      await tester.tap(find.text('PhonePe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google Pay'));
      await tester.pumpAndSettle();

      expect(h.recorder.properties('UPI App Selected'), <String, Object?>{
        'upi_app': 'Google Pay',
      });
    });

    testWidgets('a cancelled payment is reported as cancelled',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(failure: const PaymentCanceled()),
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(h.recorder.events.last, 'Checkout Cancelled');
      expect(h.recorder.events, isNot(contains('Subscription Succeeded')));
    });

    testWidgets("a declined payment is reported with Cashfree's code",
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(
          failure: const PaymentFailure(
            PaymentError.declined,
            code: 'payment_failed',
          ),
        ),
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(h.recorder.properties('Checkout Failed'), <String, Object?>{
        'plan_id': 'monthly',
        'reason': 'payment_failed',
      });
    });

    testWidgets('being let in as already subscribed is not a purchase',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(
          failure: const BackendFailure(BackendError.alreadySubscribed),
        ),
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(h.recorder.events.last, 'Web Page Viewed');
      expect(h.recorder.events, isNot(contains('Subscription Succeeded')));
      expect(h.recorder.otherMethods, isNot(contains('metaSubscribe')));
    });

    testWidgets('logging out is tracked, then the identity is reset',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);
      await tapTryNow(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(h.recorder.events, containsAllInOrder(<String>[
        'Signed Out',
        'Phone Entry Viewed',
      ]));
      expect(h.recorder.otherMethods.last, 'reset');
    });
  });
}
