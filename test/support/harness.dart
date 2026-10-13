import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes/main.dart';
import 'package:notes/providers.dart';
import 'package:notes/services/analytics.dart';
import 'package:notes/services/deep_link_service.dart';
import 'package:notes/services/evos_backend.dart';
import 'package:notes/services/onboarding_store.dart';
import 'package:notes/services/payment_gateway.dart';

// Shared by the widget tests that pump the real NotesApp. Firebase is never
// initialised: the only Firebase-backed provider the signed-out path reads is
// authStateProvider, which is overridden with a signed-out stream.

const String onboardingLink = 'https://$kDeepLinkHost/onboarding';

const String phone = '9876543210';
const String rightCode = '123456';

/// Records what would have gone to the native analytics SDKs.
class Recorder implements AnalyticsClient {
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];

  @override
  void send(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) =>
      calls.add((method, arguments));

  /// Mixpanel event names, in the order sent.
  List<String> get events => <String>[
        for (final (String method, Map<String, Object?> arguments) in calls)
          if (method == 'track') arguments['event']! as String,
      ];

  Map<String, Object?> properties(String event) {
    final (String, Map<String, Object?>) call = calls.firstWhere(
      ((String, Map<String, Object?>) c) =>
          c.$1 == 'track' && c.$2['event'] == event,
    );
    return call.$2['properties']! as Map<String, Object?>;
  }

  /// Every channel method other than a Mixpanel event, in the order sent.
  List<String> get otherMethods => <String>[
        for (final (String method, Map<String, Object?> _) in calls)
          if (method != 'track') method,
      ];
}

/// Stands in for Supabase. Each `...Error` field makes that call fail.
class FakeBackend implements EvosBackend {
  FakeBackend(this._store);

  final OnboardingStore _store;

  Map<String, String> config = <String, String>{};
  bool subscribed = false;
  bool newUser = false;

  BackendError? sendError;
  BackendError? verifyError;
  BackendError? configError;
  BackendError? subscriptionError;

  final List<String> codesSentTo = <String>[];
  int signOuts = 0;

  // Long enough for a busy state to be seen, as a real call would be.
  static const Duration _delay = Duration(milliseconds: 50);

  @override
  bool get isSignedIn => _store.loadSession() != null;

  @override
  Future<void> sendOtp(String phoneE164) async {
    await Future<void>.delayed(_delay);
    if (sendError != null) throw BackendFailure(sendError!);
    codesSentTo.add(phoneE164);
  }

  @override
  Future<SignInResult> verifyOtp(String phoneE164, String code) async {
    await Future<void>.delayed(_delay);
    if (verifyError != null) throw BackendFailure(verifyError!);
    if (code != rightCode) throw const BackendFailure(BackendError.wrongCode);
    await _store.saveSession('fake-session');
    return SignInResult(userId: 'user-1', isNewUser: newUser);
  }

  @override
  Future<void> signOut() async {
    signOuts += 1;
    await _store.clearSession();
  }

  @override
  Future<Map<String, String>> fetchConfig() async {
    if (configError != null) throw BackendFailure(configError!);
    return config;
  }

  @override
  Future<bool> hasActiveSubscription() async {
    if (subscriptionError != null) throw BackendFailure(subscriptionError!);
    return subscribed;
  }

  @override
  Future<SubscriptionSession> createSubscription() =>
      throw UnimplementedError('Payments go through FakeGateway.');

  @override
  Future<bool> verifySubscription(String subscriptionId) =>
      throw UnimplementedError('Payments go through FakeGateway.');
}

/// Stands in for Cashfree. [failure] is thrown by `subscribe` when set.
class FakeGateway implements PaymentGateway {
  FakeGateway({
    this.failure,
    this.isSimulated = false,
    this.apps = const <UpiApp>[
      UpiApp(packageName: 'com.phonepe.app', name: 'PhonePe'),
      UpiApp(
        packageName: 'com.google.android.apps.nbu.paisa.user',
        name: 'Google Pay',
      ),
    ],
  });

  Object? failure;
  final List<UpiApp> apps;
  final List<String> paidWith = <String>[];

  @override
  final bool isSimulated;

  @override
  Future<List<UpiApp>> upiApps() async => apps;

  @override
  Future<void> subscribe(UpiApp app) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (failure != null) throw failure!;
    paidWith.add(app.name);
  }
}

class Harness {
  Harness(this.recorder, this.backend, this.gateway);

  final Recorder recorder;
  final FakeBackend backend;
  final FakeGateway gateway;
}

/// Starts the app the way `main()` does, minus Firebase. [setup] runs before
/// the first frame, to arrange what the server will say.
Future<Harness> launch(
  WidgetTester tester, {
  String? coldStartLink,
  String? installReferrer,
  FakeGateway? gateway,
  void Function(FakeBackend backend)? setup,
}) async {
  if (coldStartLink != null) {
    tester.platformDispatcher.defaultRouteNameTestValue = coldStartLink;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  final DeepLinkService deepLinks = DeepLinkService(tester.binding)..start();
  addTearDown(deepLinks.dispose);
  final OnboardingStore store = await OnboardingStore.open();
  final Harness harness = Harness(
    Recorder(),
    FakeBackend(store),
    gateway ?? FakeGateway(),
  );
  setup?.call(harness.backend);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        analyticsProvider.overrideWithValue(Analytics(harness.recorder)),
        deepLinkServiceProvider.overrideWithValue(deepLinks),
        onboardingStoreProvider.overrideWithValue(store),
        installReferrerProvider.overrideWithValue(installReferrer),
        evosBackendProvider.overrideWithValue(harness.backend),
        paymentGatewayProvider.overrideWithValue(harness.gateway),
        authStateProvider.overrideWith((Ref ref) => Stream<User?>.value(null)),
      ],
      child: const NotesApp(),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// Delivers a link the way the engine does while the app is running.
Future<void> openLinkWhileRunning(WidgetTester tester, String link) async {
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

/// Both sign-in screens have exactly one text field.
Future<void> sendCode(WidgetTester tester, [String number = phone]) async {
  await tester.enterText(find.byType(TextField), number);
  await tester.pump();
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();
}

/// The sixth digit submits by itself.
Future<void> enterCode(WidgetTester tester, [String code = rightCode]) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester) async {
  await sendCode(tester);
  await enterCode(tester);
}

Future<void> tapTryNow(WidgetTester tester) async {
  await tester.tap(find.text('Try Now'));
  await tester.pumpAndSettle();
}
