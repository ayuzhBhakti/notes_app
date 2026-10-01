import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes/main.dart';
import 'package:notes/models/onboarding.dart';
import 'package:notes/providers.dart';
import 'package:notes/services/deep_link_service.dart';
import 'package:notes/services/leads_repository.dart';
import 'package:notes/services/onboarding_store.dart';
import 'package:notes/services/payment_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

// These pump the real NotesApp. Firebase is never initialised: the only
// Firebase-backed provider the signed-out path reads is authStateProvider,
// which is overridden with a signed-out stream.

const String _link = 'https://$kDeepLinkHost/onboarding';

class _FailingGateway extends SimulatedPaymentGateway {
  const _FailingGateway() : super(delay: Duration.zero);

  @override
  Future<void> purchase(Plan plan) async => throw StateError('Card declined.');
}

class _CancelingGateway extends SimulatedPaymentGateway {
  const _CancelingGateway() : super(delay: Duration.zero);

  @override
  Future<void> purchase(Plan plan) async => throw const PaymentCanceled();
}

/// Stands in for Supabase and records what would have been sent.
class _FakeLeads implements LeadsRepository {
  _FakeLeads({this.fail = false});

  bool fail;
  final List<LeadDetails> saved = <LeadDetails>[];

  @override
  Future<void> save(LeadDetails details) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (fail) throw const LeadSaveFailure();
    saved.add(details);
  }
}

/// Starts the app the way `main()` does, minus Firebase.
Future<void> _launch(
  WidgetTester tester, {
  String? coldStartLink,
  String? installReferrer,
  LeadsRepository? leads,
  PaymentGateway gateway = const SimulatedPaymentGateway(
    delay: Duration(milliseconds: 50),
  ),
}) async {
  if (coldStartLink != null) {
    tester.platformDispatcher.defaultRouteNameTestValue = coldStartLink;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  final DeepLinkService deepLinks = DeepLinkService(tester.binding)..start();
  addTearDown(deepLinks.dispose);
  final OnboardingStore store = await OnboardingStore.open();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        deepLinkServiceProvider.overrideWithValue(deepLinks),
        onboardingStoreProvider.overrideWithValue(store),
        paymentGatewayProvider.overrideWithValue(gateway),
        installReferrerProvider.overrideWithValue(installReferrer),
        leadsRepositoryProvider.overrideWithValue(leads ?? _FakeLeads()),
        authStateProvider.overrideWith((Ref ref) => Stream<User?>.value(null)),
      ],
      child: const NotesApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Delivers a link the way the engine does while the app is running.
Future<void> _openLinkWhileRunning(WidgetTester tester, String link) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', <String, Object?>{
        'location': link,
        'state': null,
      }),
    ),
    (ByteData? _) {},
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(_field('Full name'), 'Asha Rao');
  await tester.enterText(_field('Email'), 'asha@example.com');
  await tester.enterText(_field('Phone'), '+91 98765 43210');
  await tester.enterText(_field('Address'), '12 MG Road, Bengaluru');
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _tapSubscribe(WidgetTester tester) async {
  final Finder button = find.textContaining('Subscribe for');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('an ordinary launch shows the normal app', (tester) async {
    await _launch(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Tell us about you'), findsNothing);
  });

  testWidgets('a cold-start onboarding link shows the details form',
      (tester) async {
    await _launch(tester, coldStartLink: _link);

    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    // The link must not have been pushed as a named route.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the local test link at cold start shows the details form',
      (tester) async {
    await _launch(tester, coldStartLink: 'notes://onboarding');
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the local test link opened while running shows the form',
      (tester) async {
    await _launch(tester);
    await _openLinkWhileRunning(tester, 'notes://onboarding');
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cold-start link to anywhere else shows the normal app',
      (tester) async {
    await _launch(tester, coldStartLink: 'https://$kDeepLinkHost/other');

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an install from a Play Store onboarding link shows the form',
      (tester) async {
    await _launch(
      tester,
      installReferrer: 'utm_source=mail&flow=onboarding',
    );

    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('an install from any other Play Store link shows the normal app',
      (tester) async {
    await _launch(
      tester,
      installReferrer: 'utm_source=google-play&utm_medium=organic',
    );

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Continue saves the trimmed details before the paywall',
      (tester) async {
    final _FakeLeads leads = _FakeLeads();
    await _launch(tester, coldStartLink: _link, leads: leads);

    await _fillForm(tester);
    await tester.enterText(_field('Full name'), '  Asha Rao  ');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // Still on the form, busy, while the save is in flight.
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(leads.saved, isEmpty);

    await tester.pumpAndSettle();

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(leads.saved, hasLength(1));
    expect(leads.saved.single.name, 'Asha Rao');
    expect(leads.saved.single.email, 'asha@example.com');
    expect(leads.saved.single.phone, '+91 98765 43210');
    expect(leads.saved.single.address, '12 MG Road, Bengaluru');
  });

  testWidgets('a failed save shows an error, stays on the form, and can retry',
      (tester) async {
    final _FakeLeads leads = _FakeLeads(fail: true);
    await _launch(tester, coldStartLink: _link, leads: leads);
    await _fillForm(tester);

    await _tapContinue(tester);

    expect(find.text("We couldn't save your details."), findsOneWidget);
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.text('Choose your plan'), findsNothing);
    // What was typed is still there.
    expect(find.text('Asha Rao'), findsOneWidget);

    leads.fail = false;
    await _tapContinue(tester);

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(leads.saved, hasLength(1));
  });

  testWidgets('an invalid form sends nothing to the server', (tester) async {
    final _FakeLeads leads = _FakeLeads();
    await _launch(tester, coldStartLink: _link, leads: leads);

    await _tapContinue(tester);

    expect(leads.saved, isEmpty);
  });

  testWidgets('a link opened while running switches to the details form',
      (tester) async {
    await _launch(tester);
    expect(find.text('Continue with Google'), findsOneWidget);

    await _openLinkWhileRunning(tester, _link);

    expect(find.text('Tell us about you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unrelated link opened while running is ignored',
      (tester) async {
    await _launch(tester);

    await _openLinkWhileRunning(tester, 'https://$kDeepLinkHost/other');

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an incomplete form shows errors and does not advance',
      (tester) async {
    await _launch(tester, coldStartLink: _link);

    await tester.enterText(_field('Email'), 'not-an-email');
    await _tapContinue(tester);

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your phone number.'), findsOneWidget);
    expect(find.text('Enter your address.'), findsOneWidget);
    expect(find.text('Choose your plan'), findsNothing);
  });

  testWidgets('form, paywall and purchase lead to the member home',
      (tester) async {
    await _launch(tester, coldStartLink: _link);

    await _fillForm(tester);
    await _tapContinue(tester);

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text('Pick a plan to finish setting up, Asha.'), findsOneWidget);
    expect(find.text('Test mode: no payment is taken.'), findsOneWidget);
    // The first plan is preselected.
    expect(find.text('Subscribe for ₹1,499 / year'), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Subscribe for ₹199 / month'), findsOneWidget);

    await _tapSubscribe(tester);

    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Monthly plan · ₹199 / month'), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('12 MG Road, Bengaluru'), findsOneWidget);
  });

  testWidgets('back from the paywall returns to a pre-filled form',
      (tester) async {
    await _launch(tester, coldStartLink: _link);
    await _fillForm(tester);
    await _tapContinue(tester);

    await tester.tap(find.byTooltip('Edit details'));
    await tester.pumpAndSettle();

    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
  });

  testWidgets('a failed payment shows an error and stays on the paywall',
      (tester) async {
    await _launch(
      tester,
      coldStartLink: _link,
      gateway: const _FailingGateway(),
    );
    await _fillForm(tester);
    await _tapContinue(tester);

    await _tapSubscribe(tester);

    expect(find.text('Card declined.'), findsOneWidget);
    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text("You're all set"), findsNothing);
  });

  testWidgets('a cancelled payment stays on the paywall without an error',
      (tester) async {
    await _launch(
      tester,
      coldStartLink: _link,
      gateway: const _CancelingGateway(),
    );
    await _fillForm(tester);
    await _tapContinue(tester);

    await _tapSubscribe(tester);

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text("You're all set"), findsNothing);
    expect(find.textContaining('Subscribe for'), findsOneWidget);
  });

  testWidgets('the stage survives a restart with no link', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_v1': const OnboardingState(
        stage: OnboardingStage.paywall,
        details: LeadDetails(
          name: 'Asha Rao',
          email: 'asha@example.com',
          phone: '9876543210',
          address: '12 MG Road',
        ),
      ).encode(),
    });

    await _launch(tester);

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('progress is saved as the user advances', (tester) async {
    await _launch(tester, coldStartLink: _link);
    await _fillForm(tester);
    await _tapContinue(tester);
    await _tapSubscribe(tester);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final OnboardingState saved =
        OnboardingState.decode(prefs.getString('onboarding_v1'));

    expect(saved.stage, OnboardingStage.member);
    expect(saved.planId, 'yearly');
    expect(saved.details!.name, 'Asha Rao');
  });

  testWidgets('opening the link again keeps the progress made',
      (tester) async {
    await _launch(tester, coldStartLink: _link);
    await _fillForm(tester);
    await _tapContinue(tester);
    expect(find.text('Choose your plan'), findsOneWidget);

    await _openLinkWhileRunning(tester, _link);

    expect(find.text('Choose your plan'), findsOneWidget);
  });

  testWidgets('the debug reset returns to the normal app', (tester) async {
    await _launch(tester, coldStartLink: _link);
    await _fillForm(tester);
    await _tapContinue(tester);
    await _tapSubscribe(tester);

    await tester.tap(find.text('Reset deep-link flow (debug only)'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('onboarding_v1'), isNull);
  });
}
