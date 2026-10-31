import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evos/models/onboarding.dart';
import 'package:evos/models/review_account.dart';
import 'package:evos/services/deep_link_service.dart';
import 'package:evos/services/evos_backend.dart';
import 'package:evos/services/payment_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

const String _googleSignIn = 'Continue with Google';
const String _phoneScreen = 'Welcome to Evos';
const String _codeScreen = 'Enter the code';
const String _noPage = "You're all set";
final Finder _webScreen = find.bySemanticsIdentifier('web_screen');

/// What a device holds after signing in and reaching [stage].
Map<String, Object> _saved(OnboardingStage stage, {bool signedIn = true}) =>
    <String, Object>{
      'onboarding_v1': OnboardingState(stage: stage).encode(),
      if (signedIn) 'evos_session_v1': 'fake-session',
    };

Future<OnboardingState> _savedState() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return OnboardingState.decode(prefs.getString('onboarding_v1'));
}

Future<OnboardingStage> _savedStage() async => (await _savedState()).stage;

/// The review account's notes screen: log out lives on the Profile screen.
Future<void> _logOutNotes(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier('notes_profile_button'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
  await tester.pumpAndSettle();
}

/// The notes list the review account lands on.
final Finder _notesScreen = find.text('Notes');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('start', () {
    testWidgets('an ordinary launch shows the mobile-number screen',
        (tester) async {
      await launch(tester);

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.text(_googleSignIn), findsNothing);
    });

    testWidgets('a cold-start onboarding link is reported and changes nothing',
        (tester) async {
      final Harness h = await launch(tester, coldStartLink: onboardingLink);

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(h.recorder.properties('Deep Link Opened')['after_install'], false);
      // The link must not have been pushed as a named route.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a link opened while running keeps the screen',
        (tester) async {
      final Harness h = await launch(tester);
      await sendCode(tester);

      await openLinkWhileRunning(tester, 'notes://onboarding');

      expect(find.text(_codeScreen), findsOneWidget);
      expect(h.recorder.events, contains('Deep Link Opened'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a link to anywhere else is not reported', (tester) async {
      final Harness h = await launch(
        tester,
        coldStartLink: 'https://$kDeepLinkHost/other',
      );

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(h.recorder.events, isNot(contains('Deep Link Opened')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an install from a Play Store onboarding link is reported',
        (tester) async {
      final Harness h = await launch(
        tester,
        installReferrer: 'utm_source=mail&flow=onboarding',
      );

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(h.recorder.properties('Deep Link Opened')['after_install'], true);
    });
  });

  group('review account', () {
    testWidgets('signs in with the fixed code, without an SMS, onto notes',
        (tester) async {
      final Harness h = await launch(tester);

      await sendCode(tester, kReviewPhone);
      expect(find.text(_codeScreen), findsOneWidget);
      await enterCode(tester, kReviewCode);

      expect(_notesScreen, findsOneWidget);
      expect(find.text('New note'), findsOneWidget);
      expect(find.text('Try Now'), findsNothing);
      expect(_webScreen, findsNothing);
      expect(h.backend.codesSentTo, isEmpty);
      expect(h.backend.isSignedIn, isFalse);
      expect(h.recorder.events, contains('Review Account Signed In'));
      // No account to tie events to.
      expect(h.recorder.otherMethods, isNot(contains('identify')));
      final OnboardingState saved = await _savedState();
      expect(saved.stage, OnboardingStage.notes);
      expect(saved.reviewAccount, isTrue);
    });

    testWidgets('can create a note, which is kept on the device', (tester) async {
      await launch(tester);
      await sendCode(tester, kReviewPhone);
      await enterCode(tester, kReviewCode);

      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.bySemanticsIdentifier('note_title_field'),
        'Groceries',
      );
      await tester.tap(find.bySemanticsIdentifier('note_save_button'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsOneWidget);
      // It is the local store, not Supabase, that holds it.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('local_notes_v1'), contains('Groceries'));
    });

    testWidgets('any other code is wrong', (tester) async {
      await launch(tester);
      await sendCode(tester, kReviewPhone);

      await enterCode(tester, '654321');

      expect(find.textContaining("That code isn't right"), findsOneWidget);
      expect(find.text(_codeScreen), findsOneWidget);
    });

    testWidgets('the same number from another country is an ordinary number',
        (tester) async {
      final Harness h = await launch(tester);
      await tester.tap(find.bySemanticsIdentifier('country_picker'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'united states');
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States').first);
      await tester.pumpAndSettle();

      await sendCode(tester, kReviewPhone);

      expect(h.backend.codesSentTo, <String>['+1$kReviewPhone']);
    });

    testWidgets('stays on notes across a restart with no session, and the '
        'server is not asked', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_v1': const OnboardingState(
          stage: OnboardingStage.notes,
          reviewAccount: true,
        ).encode(),
      });

      await launch(
        tester,
        setup: (FakeBackend b) => b.subscriptionError = BackendError.signedOut,
      );

      expect(_notesScreen, findsOneWidget);
    });

    testWidgets('Log out returns to the number without calling the server',
        (tester) async {
      final Harness h = await launch(tester);
      await sendCode(tester, kReviewPhone);
      await enterCode(tester, kReviewCode);

      await _logOutNotes(tester);

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(h.backend.signOuts, 0);
      expect(await _savedState(), isA<OnboardingState>()
          .having((OnboardingState s) => s.reviewAccount, 'review', isFalse));
    });
  });

  group('mobile number', () {
    testWidgets('Send code stays off until the number is valid',
        (tester) async {
      final Harness h = await launch(tester);
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
      await launch(tester);

      await tester.enterText(find.byType(TextField), '+91 98765 43210');
      await tester.pump();

      expect(find.text(phone), findsOneWidget);
    });

    testWidgets('an autofilled 91-prefixed number keeps all 10 national digits',
        (tester) async {
      await launch(tester);

      // A keyboard suggestion / autofill of the full number, no + or spaces
      // (the case that used to keep only the first 10: 9198765432).
      await tester.enterText(find.byType(TextField), '919876543210');
      await tester.pump();

      expect(find.text(phone), findsOneWidget);
    });

    testWidgets('a leading trunk 0 is dropped', (tester) async {
      await launch(tester);

      await tester.enterText(find.byType(TextField), '09876543210');
      await tester.pump();

      expect(find.text(phone), findsOneWidget);
    });

    testWidgets('Send code texts the number and opens the code screen',
        (tester) async {
      final Harness h = await launch(tester);

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
      final Harness h = await launch(tester);
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
      await launch(tester);
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

    testWidgets(
        'a first launch waits for slow settings, then shows the carousel '
        'with the keyboard closed', (tester) async {
      await launch(
        tester,
        setup: (FakeBackend b) => b
          ..config = slides
          ..configDelay = const Duration(seconds: 1),
        settle: false,
      );

      // No form yet: drawn now, it would have no carousel and open the
      // keyboard, and the carousel would arrive behind it.
      expect(find.text(_phoneScreen), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('login_carousel'), findsOneWidget);
      expect(find.text('Hear every payment'), findsOneWidget);
      expect(find.text(_phoneScreen), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('settings that never answer still show the form',
        (tester) async {
      await launch(
        tester,
        setup: (FakeBackend b) =>
            b.configDelay = const Duration(seconds: 30),
        settle: false,
      );
      expect(find.text(_phoneScreen), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.bySemanticsIdentifier('login_carousel'), findsNothing);
      // Let the slow answer arrive before the test ends.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('with no slides from the backend there is no carousel',
        (tester) async {
      await launch(tester);
      expect(find.bySemanticsIdentifier('login_carousel'), findsNothing);
    });

    testWidgets('slides arriving after the form is shown do not rearrange it',
        (tester) async {
      // A saved config with no slides settles at once, so the form shows
      // without a carousel; the refresh then brings slides.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'evos_config_v1': '{"app_name":"Evos"}',
      });

      await launch(
        tester,
        setup: (FakeBackend b) => b.config = <String, String>{
          'login_slide_images': 'https://cdn.example.com/1.png',
          'login_slide_titles': 'Hear every payment',
        },
      );

      // The late slides must not swap in the carousel layout under the user.
      expect(find.text('Welcome to Evos'), findsOneWidget);
      expect(find.bySemanticsIdentifier('login_carousel'), findsNothing);
      expect(find.text('Hear every payment'), findsNothing);
    });
  });

  group('code', () {
    testWidgets('the sixth digit signs in without a button', (tester) async {
      await launch(tester);
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
      await launch(tester);
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
      await launch(tester);
      await sendCode(tester);

      await tester.tap(find.byTooltip('Change number'));
      await tester.pumpAndSettle();

      expect(find.text(_phoneScreen), findsOneWidget);
      expect(find.text(phone), findsOneWidget);
    });

    testWidgets('a new code can be asked for after the wait, not before',
        (tester) async {
      final Harness h = await launch(tester);
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
        setup: (FakeBackend b) => b.subscribed = true,
      );

      await signIn(tester);

      expect(_webScreen, findsOneWidget);
      expect(find.text('Try Now'), findsNothing);
    });
  });

  group('paywall', () {
    testWidgets('shows the name, prices and words the backend sent',
        (tester) async {
      await launch(
        tester,
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
      // The pill and the large price; no struck-through monthly price.
      expect(find.text('₹5'), findsNWidgets(2));
      expect(find.text('₹499'), findsNothing);
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

    testWidgets('the video card has the backend shape even when it fails',
        (tester) async {
      await launch(
        tester,
        setup: (FakeBackend b) => b.config = <String, String>{
          'paywall_video_url': 'https://cdn.example.com/preview.mp4',
          'paywall_preview_image_url': 'https://cdn.example.com/poster.jpg',
          'paywall_video_aspect_ratio': '9:16',
        },
      );
      await signIn(tester);

      // The 800 x 600 test screen: 752 wide after padding, and at most 45%
      // of 600 tall, so a 9:16 card is 270 tall and 151.875 wide. The
      // picture stands in for the video in the same box.
      expect(tester.getSize(find.byType(Image)), const Size(151.875, 270));
    });

    testWidgets('every word and icon can come from the backend',
        (tester) async {
      await launch(
        tester,
        gateway: FakeGateway(apps: const <UpiApp>[]),
        setup: (FakeBackend b) => b.config = <String, String>{
          'cashfree_trial_amount': '5',
          'cashfree_recurring_amount': '499',
          'paywall_subtitle': 'Everything, for one rupee a day',
          'paywall_features': 'Alpha|Beta',
          'paywall_feature_icons': 'lock|',
          'paywall_show_strike_price': 'false',
          'paywall_autopay_text': 'Pay {trial} now, then {recurring} a month.',
          'paywall_social_proofs': 'Asha just joined',
          'paywall_social_proof_icon': 'bolt',
          'paywall_cta_text': 'Start now',
          'paywall_upi_select_text': 'Choose an app',
          'paywall_upi_sheet_title': 'Pick your UPI app',
        },
      );
      await signIn(tester);

      expect(find.text('Everything, for one rupee a day'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      // The second feature has no icon of its own: a tick.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      // No struck-through monthly price.
      expect(find.text('₹499'), findsNothing);
      expect(find.text('Pay ₹5 now, then ₹499 a month.'), findsOneWidget);
      expect(find.text('Choose an app'), findsOneWidget);
      expect(find.text('Try Now'), findsNothing);

      await tester.tap(find.text('Start now'));
      await tester.pumpAndSettle();
      expect(find.text('Pick your UPI app'), findsOneWidget);
    });

    testWidgets('takes its colour from the backend', (tester) async {
      await launch(
        tester,
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
      await launch(tester);
      await signIn(tester);

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.text('₹3'), findsNWidgets(2));
      // The struck-through monthly price is off unless the backend turns it on.
      expect(find.text('₹299'), findsNothing);
    });

    testWidgets('the backend can turn the struck-through price back on',
        (tester) async {
      await launch(
        tester,
        setup: (FakeBackend b) => b.config = <String, String>{
          'paywall_show_strike_price': 'true',
        },
      );
      await signIn(tester);
      expect(find.text('₹299'), findsOneWidget);
    });

    testWidgets('Try Now pays with the first UPI app and opens the web page',
        (tester) async {
      final Harness h = await launch(tester);
      await signIn(tester);
      expect(find.text('PhonePe'), findsOneWidget);

      await tester.tap(find.text('Try Now'));
      await tester.pump();
      // The processing screen covers the paywall, not a button spinner.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('payment'), findsWidgets);
      await tester.pumpAndSettle();

      expect(_webScreen, findsOneWidget);
      expect(h.gateway.paidWith, <String>['PhonePe']);
      expect(h.gateway.stages, contains(CheckoutStage.confirming));
      expect(await _savedStage(), OnboardingStage.web);
    });

    testWidgets('Back on the processing screen stops the payment and stays',
        (tester) async {
      final Harness h = await launch(tester);
      await signIn(tester);

      await tester.tap(find.text('Try Now'));
      await tester.pump();
      expect(find.text('Getting your payment ready'), findsOneWidget);

      // The system back button, which PopScope turns into "leave".
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.text('Getting your payment ready'), findsNothing);
      expect(_webScreen, findsNothing);
      expect(h.gateway.paidWith, isEmpty);
    });

    testWidgets('a late approval after a cancel lets the user in by itself',
        (tester) async {
      final Harness h = await launch(
        tester,
        gateway: FakeGateway(failure: const PaymentCanceled())
          ..lateConfirm = true,
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(h.gateway.lateChecks, 1);
      expect(_webScreen, findsOneWidget);
    });

    testWidgets('another UPI app can be chosen', (tester) async {
      final Harness h = await launch(tester);
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
        gateway: FakeGateway(
          failure: const PaymentFailure(PaymentError.declined),
        ),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(find.textContaining("The payment didn't go through."),
          findsOneWidget);
      expect(find.text('Try Now'), findsOneWidget);
      expect(_webScreen, findsNothing);
    });

    testWidgets('a cancelled payment stays without an error', (tester) async {
      await launch(
        tester,
        gateway: FakeGateway(failure: const PaymentCanceled()),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.textContaining("didn't go through"), findsNothing);
      expect(_webScreen, findsNothing);
    });

    testWidgets('a server failure shows the code the server gave',
        (tester) async {
      final Harness h = await launch(
        tester,
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
        gateway: FakeGateway(
          failure: const BackendFailure(BackendError.alreadySubscribed),
        ),
      );
      await signIn(tester);

      await tapTryNow(tester);

      expect(_webScreen, findsOneWidget);
    });

    testWidgets('only a simulated gateway shows the test-mode notice',
        (tester) async {
      await launch(
        tester,
        gateway: FakeGateway(isSimulated: true),
      );
      await signIn(tester);
      expect(find.text('Test mode: no payment is taken.'), findsOneWidget);
    });

    testWidgets('a real gateway shows no test-mode notice', (tester) async {
      await launch(tester);
      await signIn(tester);
      expect(find.text('Test mode: no payment is taken.'), findsNothing);
    });

    testWidgets('has no Log out', (tester) async {
      await launch(tester);
      await signIn(tester);

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets('the web page is full screen: no app bar, Log out or Reload',
        (tester) async {
      await launch(
        tester,
        setup: (FakeBackend b) => b.config = <String, String>{
          'webview_url': 'https://app.example.com/',
        },
      );
      await signIn(tester);
      await tapTryNow(tester);

      expect(find.bySemanticsIdentifier('web_screen'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Log out'), findsNothing);
      expect(find.byTooltip('Reload'), findsNothing);
      expect(find.byTooltip('More'), findsNothing);
    });
  });

  group('web page', () {
    testWidgets('with no URL from the backend, says it is not ready',
        (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.web));
      final Harness h = await launch(
        tester,
        setup: (FakeBackend b) => b.subscribed = true,
      );

      expect(find.text(_noPage), findsOneWidget);
      expect(h.recorder.properties('Web Page Viewed')['has_url'], false);
    });

    testWidgets('Check again picks up a URL set meanwhile', (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.web));
      final Harness h = await launch(
        tester,
        setup: (FakeBackend b) => b.subscribed = true,
      );

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing new yet. Check back later.'), findsOneWidget);
      // Let the message go: it sits over the button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      h.backend.config = <String, String>{
        'webview_url': 'https://app.example.com/',
      };
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text(_noPage), findsNothing);
      // No WebView exists in a widget test; on a phone the page shows here.
      expect(find.text('This page cannot be shown on this device.'),
          findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('a URL that is not https is not loaded', (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.web));
      await launch(
        tester,
        setup: (FakeBackend b) => b
          ..subscribed = true
          ..config = <String, String>{'webview_url': 'http://app.example.com/'},
      );

      expect(find.text(_noPage), findsOneWidget);
    });

    testWidgets("a tagged source gets that source's page, not the global one",
        (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.web));
      final Harness h = await launch(
        tester,
        installSource: 'filmyface',
        setup: (FakeBackend b) => b
          ..subscribed = true
          ..config = <String, String>{
            'webview_url': 'https://default.example.com/',
          }
          ..webUrlBySource = <String, String>{
            'filmyface': 'https://filmyface.example.com/evos',
          },
      );

      // No WebView renders in a test, so a present page shows this instead of
      // the "all set" screen; the cached config proves which URL it is.
      expect(find.text(_noPage), findsNothing);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('evos_config_v1'),
          contains('filmyface.example.com'));
      // The source is on the view event so a misroute is visible in Mixpanel.
      expect(h.recorder.properties('Web Page Viewed')['config_source'],
          'filmyface');
    });

    testWidgets('without a source, the global web page is used',
        (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.web));
      await launch(
        tester,
        setup: (FakeBackend b) => b
          ..subscribed = true
          ..config = <String, String>{
            'webview_url': 'https://default.example.com/',
          }
          ..webUrlBySource = <String, String>{
            'filmyface': 'https://filmyface.example.com/evos',
          },
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString('evos_config_v1'), contains('default.example.com'));
      expect(prefs.getString('evos_config_v1'), isNot(contains('filmyface')));
    });
  });

  group('restart', () {
    testWidgets('the stage survives a restart', (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.paywall));

      await launch(tester);

      expect(find.text('Try Now'), findsOneWidget);
    });

    testWidgets('a device saved at maintenance by an older build opens the '
        'web page', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_v1': '{"stage":"maintenance"}',
        'evos_session_v1': 'fake-session',
      });

      await launch(tester, setup: (FakeBackend b) => b.subscribed = true);

      expect(_webScreen, findsOneWidget);
    });

    testWidgets('a device that was on the notes app signs in by phone',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_v1': '{"stage":"inactive"}',
      });

      await launch(tester);

      expect(find.text(_phoneScreen), findsOneWidget);
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
        _saved(OnboardingStage.web, signedIn: false),
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
        _saved(OnboardingStage.web),
      );

      await launch(tester, setup: (FakeBackend b) => b.subscribed = false);

      expect(find.text('Try Now'), findsOneWidget);
      expect(await _savedStage(), OnboardingStage.paywall);
    });

    testWidgets('a payment the device never heard about is found at start',
        (tester) async {
      SharedPreferences.setMockInitialValues(_saved(OnboardingStage.paywall));

      await launch(tester, setup: (FakeBackend b) => b.subscribed = true);

      expect(_webScreen, findsOneWidget);
    });

    testWidgets('offline, a subscriber is not sent back to the paywall',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.web),
      );

      await launch(
        tester,
        setup: (FakeBackend b) => b
          ..configError = BackendError.network
          ..subscriptionError = BackendError.network,
      );

      expect(_webScreen, findsOneWidget);
    });

    testWidgets('a sign-in the server no longer accepts signs in again',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        _saved(OnboardingStage.web),
      );

      await launch(
        tester,
        setup: (FakeBackend b) => b.subscriptionError = BackendError.signedOut,
      );

      expect(find.text(_phoneScreen), findsOneWidget);
    });

    testWidgets('opening the link again keeps the progress made',
        (tester) async {
      await launch(tester);
      await signIn(tester);
      expect(find.text('Try Now'), findsOneWidget);

      await openLinkWhileRunning(tester, onboardingLink);

      expect(find.text('Try Now'), findsOneWidget);
    });

    testWidgets('no screen offers Google sign-in', (tester) async {
      await launch(tester);
      expect(find.text(_googleSignIn), findsNothing);
      await signIn(tester);
      expect(find.text(_googleSignIn), findsNothing);
      await tapTryNow(tester);
      expect(find.text(_googleSignIn), findsNothing);
    });
  });
}
