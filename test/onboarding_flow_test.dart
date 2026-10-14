import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Evos/models/onboarding.dart';
import 'package:Evos/services/deep_link_service.dart';
import 'package:Evos/services/evos_backend.dart';
import 'package:Evos/services/payment_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

const String _notesApp = 'Continue with Google';
const String _phoneScreen = 'Welcome to Evos';
const String _codeScreen = 'Enter the code';
const String _maintenance = "We're under maintenance";

/// What a device holds after signing in and reaching [stage].
Map<String, Object> _saved(OnboardingStage stage, {bool signedIn = true}) =>
    <String, Object>{
      'onboarding_v1': OnboardingState(stage: stage).encode(),
      if (signedIn) 'evos_session_v1': 'fake-session',
    };

Future<OnboardingStage> _savedStage() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return OnboardingState.decode(prefs.getString('onboarding_v1')).stage;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('which interface', () {
    testWidgets('an ordinary launch shows the normal app', (tester) async {
      await launch(tester);

      expect(find.text(_notesApp), findsOneWidget);
      expect(find.text(_phoneScreen), findsNothing);
    });

    testWidgets('a cold-start onboarding link shows the mobile-number screen',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.text(_notesApp), findsNothing);
      // The link must not have been pushed as a named route.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the local test link at cold start shows the mobile-number screen',
        (tester) async {
      await launch(tester, coldStartLink: 'notes://onboarding');
      expect(find.text(_phoneScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a link opened while running switches interface',
        (tester) async {
      await launch(tester);
      expect(find.text(_notesApp), findsOneWidget);

      await openLinkWhileRunning(tester, 'notes://onboarding');

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a link to anywhere else shows the normal app', (tester) async {
      await launch(tester, coldStartLink: 'https://$kDeepLinkHost/other');
      expect(find.text(_notesApp), findsOneWidget);

      await openLinkWhileRunning(tester, 'https://$kDeepLinkHost/other');
      expect(find.text(_notesApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an install from a Play Store onboarding link signs in',
        (tester) async {
      await launch(tester, installReferrer: 'utm_source=mail&flow=onboarding');

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.text(_notesApp), findsNothing);
    });

    testWidgets('an install from any other Play Store link is the normal app',
        (tester) async {
      await launch(
        tester,
        installReferrer: 'utm_source=google-play&utm_medium=organic',
      );

      expect(find.text(_notesApp), findsOneWidget);
    });
  });

  group('mobile number', () {
    testWidgets('Send code stays off until the number is valid',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '98765');
      await tester.pump();
      expect(button().onPressed, isNull);
      // Not an error yet: the number is still being typed.
      expect(find.text('Enter a valid 10-digit mobile number.'), findsNothing);

      await tester.enterText(find.byType(TextField), '1234567890');
      await tester.pump();
      expect(button().onPressed, isNull);
      expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), phone);
      await tester.pump();
      expect(button().onPressed, isNotNull);
      expect(h.backend.codesSentTo, isEmpty);
    });

    testWidgets('a pasted number loses its country code, not its digits',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);

      await tester.enterText(find.byType(TextField), '+91 98765 43210');
      await tester.pump();

      expect(find.text(phone), findsOneWidget);
    });

    testWidgets('Send code texts the number and opens the code screen',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);

      await tester.enterText(find.byType(TextField), phone);
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pump();

      // Still here, busy, while the request is in flight.
      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text(_codeScreen), findsOneWidget);
      expect(find.text('Sent by SMS to +91 98765 43210'), findsOneWidget);
      expect(h.backend.codesSentTo, <String>['+919876543210']);
    });

    testWidgets('a failed send shows why, stays, and can be retried',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.sendError = BackendError.network,
      );

      await sendCode(tester);

      expect(find.textContaining("We couldn't reach the server."),
          findsOneWidget);
      expect(find.text(_phoneScreen), findsOneWidget);
      // What was typed is still there.
      expect(find.text(phone), findsOneWidget);

      h.backend.sendError = null;
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.text(_codeScreen), findsOneWidget);
    });

    testWidgets('another country can be chosen, and its code is used',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      expect(find.text('+91'), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('country_picker'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your country'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'united king');
      await tester.pumpAndSettle();
      await tester.tap(find.text('United Kingdom'));
      await tester.pumpAndSettle();

      expect(find.text('+44'), findsOneWidget);
      await sendCode(tester, '07911 123456');

      // The leading 0 is how the number is dialled inside the country only.
      expect(h.backend.codesSentTo, <String>['+447911123456']);
      expect(find.text('Sent by SMS to +44 7911123456'), findsOneWidget);
    });

    testWidgets('the country search finds a calling code', (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await tester.tap(find.bySemanticsIdentifier('country_picker'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '+971');
      await tester.pumpAndSettle();

      expect(find.text('United Arab Emirates'), findsOneWidget);
      expect(find.text('India'), findsNothing);
    });

    testWidgets('a country codes cannot reach is said plainly',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) =>
            b.sendError = BackendError.countryNotSupported,
      );

      await sendCode(tester);

      expect(find.textContaining("We can't send codes to this country yet."),
          findsOneWidget);
    });

    testWidgets('too many requests is said plainly', (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.sendError = BackendError.tooManyRequests,
      );

      await sendCode(tester);

      expect(find.textContaining('Too many attempts.'), findsOneWidget);
    });
  });

  group('login carousel', () {
    const Map<String, String> slides = <String, String>{
      'login_slide_images': 'https://cdn.example.com/1.png|'
          'https://cdn.example.com/2.png|https://cdn.example.com/3.png',
      'login_slide_titles': 'Hear every payment|Your language|Track growth',
    };

    testWidgets('shows the backend slides and moves on by itself',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.config = slides,
      );

      expect(find.bySemanticsIdentifier('login_carousel'), findsOneWidget);
      expect(find.text('Hear every payment'), findsOneWidget);
      expect(find.text(_phoneScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Your language'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      // Round again to the first.
      expect(find.text('Hear every payment'), findsOneWidget);
    });

    testWidgets('a swipe moves to the next slide', (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.config = slides,
      );

      await tester.fling(
        find.bySemanticsIdentifier('login_carousel'),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Your language'), findsOneWidget);
    });

    testWidgets('steps aside for the keyboard, which stays open',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.config = slides,
      );
      addTearDown(tester.view.resetViewInsets);

      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('login_carousel'), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byType(TextField), phone);
      await tester.pump();
      expect(find.text(phone), findsOneWidget);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('login_carousel'), findsOneWidget);
    });

    testWidgets('with no slides from the backend there is no carousel',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      expect(find.bySemanticsIdentifier('login_carousel'), findsNothing);
    });
  });

  group('code', () {
    testWidgets('the sixth digit signs in without a button', (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await sendCode(tester);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.pumpAndSettle();
      expect(find.text(_codeScreen), findsOneWidget);

      await enterCode(tester);

      expect(find.text('Try Now'), findsOneWidget);
      expect(await _savedStage(), OnboardingStage.paywall);
    });

    testWidgets('a wrong code says so, empties the boxes, and can be retried',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await sendCode(tester);

      await enterCode(tester, '000000');

      expect(find.textContaining("That code isn't right"), findsOneWidget);
      expect(find.text(_codeScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      await enterCode(tester);

      expect(find.text('Try Now'), findsOneWidget);
    });

    testWidgets('Change number goes back with the number still filled in',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await sendCode(tester);

      await tester.tap(find.byTooltip('Change number'));
      await tester.pumpAndSettle();

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.text(phone), findsOneWidget);
    });

    testWidgets('a new code can be asked for after the wait, not before',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await sendCode(tester);

      expect(find.text('Resend code'), findsNothing);
      expect(find.textContaining('Resend code in 0:'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));

      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();

      expect(h.backend.codesSentTo, hasLength(2));
      // And the wait starts again.
      expect(find.text('Resend code'), findsNothing);
    });

    testWidgets('someone who already pays skips the paywall', (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.subscribed = true,
      );

      await signIn(tester);

      expect(find.text(_maintenance), findsOneWidget);
      expect(find.text('Try Now'), findsNothing);
    });
  });

  group('paywall', () {
    testWidgets('shows the name, prices and words the backend sent',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.config = <String, String>{
          'app_name': 'Zed',
          'paywall_title_prefix': '7-Day',
          'paywall_title_suffix': 'Pass',
          'cashfree_trial_amount': '5',
          'cashfree_recurring_amount': '499',
          'paywall_features': 'Alpha|Beta',
          'paywall_rating_value': '4.6',
          'paywall_rating_caption': '(2,000 ratings)',
          'paywall_social_proofs': 'Asha just joined',
        },
      );
      expect(find.text('Welcome to Zed'), findsOneWidget);

      await signIn(tester);

      expect(find.text('Zed'), findsOneWidget);
      expect(find.text('7-Day'), findsOneWidget);
      expect(find.text('Pass'), findsOneWidget);
      // The pill and the large price.
      expect(find.text('₹5'), findsNWidgets(2));
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('(2,000 ratings)'), findsOneWidget);
      expect(find.text('Asha just joined'), findsOneWidget);
      expect(
        find.text(
          '₹5 today for the first 24 hours, then ₹499 every month by UPI '
          'AutoPay. Cancel any time in your UPI app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a video that cannot play leaves a working paywall',
        (tester) async {
      // No video plugin answers in a widget test, which is the same to the
      // paywall as a video that fails to load on a phone.
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) => b.config = <String, String>{
          'paywall_video_url': 'https://cdn.example.com/preview.mp4',
        },
      );
      await signIn(tester);

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsIdentifier('paywall_video'), findsNothing);
      await tapTryNow(tester);
      expect(h.gateway.paidWith, <String>['PhonePe']);
    });

    testWidgets('takes its colour from the backend', (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        setup: (FakeBackend b) =>
            b.config = <String, String>{'theme_color': '#0B7A5C'},
      );

      final ThemeData theme =
          Theme.of(tester.element(find.text(_phoneScreen)));
      expect(
        theme.colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B7A5C),
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).primary,
      );
      // And not the notes app's indigo.
      expect(
        theme.colorScheme.primary,
        isNot(ColorScheme.fromSeed(seedColor: Colors.indigo).primary),
      );
    });

    testWidgets('with nothing sent, shows no rating and no social proof',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.text('₹3'), findsNWidgets(2));
      expect(find.text('₹299'), findsOneWidget);
    });

    testWidgets('Try Now pays with the first UPI app and opens maintenance',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);
      expect(find.text('PhonePe'), findsOneWidget);

      await tester.tap(find.text('Try Now'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text(_maintenance), findsOneWidget);
      expect(h.gateway.paidWith, <String>['PhonePe']);
      expect(await _savedStage(), OnboardingStage.maintenance);
    });

    testWidgets('another UPI app can be chosen', (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);

      await tester.tap(find.text('PhonePe'));
      await tester.pumpAndSettle();
      expect(find.text('Pay with UPI AutoPay'), findsOneWidget);
      await tester.tap(find.text('Google Pay'));
      await tester.pumpAndSettle();

      await tapTryNow(tester);

      expect(h.gateway.paidWith, <String>['Google Pay']);
    });

    testWidgets('with no UPI app, Try Now says what to install and pays nothing',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(apps: const <UpiApp>[]),
      );
      await signIn(tester);
      expect(find.text('Select UPI App'), findsOneWidget);

      await tapTryNow(tester);

      expect(find.textContaining('No UPI app was found'), findsOneWidget);
      expect(h.gateway.paidWith, isEmpty);
    });

    testWidgets('a declined payment shows an error and stays', (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(
          failure: const PaymentFailure(PaymentError.declined),
        ),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(find.textContaining("The payment didn't go through."),
          findsOneWidget);
      expect(find.text('Try Now'), findsOneWidget);
      expect(find.text(_maintenance), findsNothing);
    });

    testWidgets('a cancelled payment stays without an error', (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(failure: const PaymentCanceled()),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.textContaining("didn't go through"), findsNothing);
      expect(find.text(_maintenance), findsNothing);
    });

    testWidgets('a server failure shows the code the server gave',
        (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(
          failure: const BackendFailure(
            BackendError.server,
            code: 'cashfree_auth_failed',
          ),
        ),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(
        find.text('Something went wrong on our side. Try again. '
            'Error code: cashfree_auth_failed'),
        findsOneWidget,
      );
      expect(h.recorder.properties('Checkout Failed')['reason'],
          'cashfree_auth_failed');
    });

    testWidgets('a payment still being confirmed is not called a failure',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(
          failure: const PaymentFailure(PaymentError.pending),
        ),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(find.textContaining("We're still confirming your payment."),
          findsOneWidget);
    });

    testWidgets('paying when already subscribed just lets the user in',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(
          failure: const BackendFailure(BackendError.alreadySubscribed),
        ),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(find.text(_maintenance), findsOneWidget);
    });

    testWidgets('only a simulated gateway shows the test-mode notice',
        (tester) async {
      await launch(
        tester,
        coldStartLink: onboardingLink,
        gateway: FakeGateway(isSimulated: true),
      );
      await signIn(tester);
      expect(find.text('Test mode: no payment is taken.'), findsOneWidget);
    });

    testWidgets('a real gateway shows no test-mode notice', (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);
      expect(find.text('Test mode: no payment is taken.'), findsNothing);
    });

    testWidgets('has no Log out', (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets('Log out on maintenance returns to the number, not to notes',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);
      await tapTryNow(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.text(_notesApp), findsNothing);
      expect(h.backend.signOuts, 1);
      expect(h.backend.isSignedIn, isFalse);
      expect(await _savedStage(), OnboardingStage.signIn);
    });
  });

  group('maintenance', () {
    testWidgets('shows the message the backend sent', (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.maintenance),
      );
      await launch(
        tester,
        setup: (FakeBackend b) => b
          ..subscribed = true
          ..config = <String, String>{
            'maintenance_title': 'Back on Monday',
            'maintenance_message': 'We are upgrading our servers.',
          },
      );

      expect(find.text('Back on Monday'), findsOneWidget);
      expect(find.text('We are upgrading our servers.'), findsOneWidget);
    });

    testWidgets('Check again picks up a changed message', (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.maintenance),
      );
      final Harness h = await launch(
        tester,
        setup: (FakeBackend b) => b.subscribed = true,
      );
      expect(find.text(_maintenance), findsOneWidget);

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing new yet. Check back later.'), findsOneWidget);

      h.backend.config = <String, String>{'maintenance_title': 'Almost there'};
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text('Almost there'), findsOneWidget);
    });
  });

  group('restart', () {
    testWidgets('the stage survives a restart with no link', (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.paywall));

      await launch(tester);

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.text(_notesApp), findsNothing);
    });

    testWidgets('the saved settings brand the very first frame',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ..._saved(OnboardingStage.signIn, signedIn: false),
        'evos_config_v1': '{"app_name":"Zed"}',
      });

      // The server cannot be reached, so only what was saved can show.
      await launch(
        tester,
        setup: (FakeBackend b) => b.configError = BackendError.network,
      );

      expect(find.text('Welcome to Zed'), findsOneWidget);
    });

    testWidgets('a paid stage with no sign-in on the device signs in again',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.maintenance, signedIn: false),
      );

      await launch(tester);

      expect(find.text(_phoneScreen), findsOneWidget);
    });

    testWidgets('a stage saved by the details-form build signs in',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_v1': '{"stage":"member","planId":"yearly","details":null}',
      });

      await launch(tester);

      expect(find.text(_phoneScreen), findsOneWidget);
    });

    testWidgets('a subscription that has ended returns to the paywall',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.maintenance),
      );

      await launch(tester, setup: (FakeBackend b) => b.subscribed = false);

      expect(find.text('Try Now'), findsOneWidget);
      expect(await _savedStage(), OnboardingStage.paywall);
    });

    testWidgets('a payment the device never heard about is found at start',
        (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.paywall));

      await launch(tester, setup: (FakeBackend b) => b.subscribed = true);

      expect(find.text(_maintenance), findsOneWidget);
    });

    testWidgets('offline, a subscriber is not sent back to the paywall',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.maintenance),
      );

      await launch(
        tester,
        setup: (FakeBackend b) => b
          ..configError = BackendError.network
          ..subscriptionError = BackendError.network,
      );

      expect(find.text(_maintenance), findsOneWidget);
    });

    testWidgets('a sign-in the server no longer accepts signs in again',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.maintenance),
      );

      await launch(
        tester,
        setup: (FakeBackend b) => b.subscriptionError = BackendError.signedOut,
      );

      expect(find.text(_phoneScreen), findsOneWidget);
    });

    testWidgets('opening the link again keeps the progress made',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      await signIn(tester);
      expect(find.text('Try Now'), findsOneWidget);

      await openLinkWhileRunning(tester, onboardingLink);

      expect(find.text('Try Now'), findsOneWidget);
    });

    testWidgets('no screen offers a way back to the notes app',
        (tester) async {
      await launch(tester, coldStartLink: onboardingLink);
      expect(find.textContaining('Reset'), findsNothing);
      await signIn(tester);
      expect(find.textContaining('Reset'), findsNothing);
      await tapTryNow(tester);
      expect(find.textContaining('Reset'), findsNothing);
    });
  });
}
