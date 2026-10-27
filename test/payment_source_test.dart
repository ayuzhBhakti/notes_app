import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:evos/services/evos_backend.dart';
import 'package:evos/services/payment_gateway.dart';

/// Records the install source passed to [createSubscription] and otherwise
/// lets the subscribe flow run to a confirmed mandate.
class _RecordingBackend implements EvosBackend {
  String? passedSource;
  bool createCalled = false;

  @override
  Future<SubscriptionSession> createSubscription(String? installSource) async {
    createCalled = true;
    passedSource = installSource;
    return const SubscriptionSession(
      subscriptionId: 'sub_1',
      sessionId: 'sess_1',
      environment: 'sandbox',
      authorizationAmount: 3,
    );
  }

  @override
  Future<bool> verifySubscription(String subscriptionId) async => true;

  @override
  Future<bool> hasActiveSubscription() async => false;

  @override
  bool get isSignedIn => true;

  @override
  Future<Map<String, String>> fetchConfig(String? installSource) async =>
      <String, String>{};

  @override
  Future<void> sendOtp(String phoneE164) async {}

  @override
  Future<SignInResult> verifyOtp(String phoneE164, String code) async =>
      const SignInResult(userId: 'u', isNewUser: false);

  @override
  Future<void> signOut() async {}
}

/// A platform that opens instantly and never calls back, so the gateway
/// falls through to the server confirmation (verifySubscription).
class _FakePlatform implements PaymentsPlatform {
  final StreamController<CashfreeResult> _results =
      StreamController<CashfreeResult>.broadcast();

  @override
  Future<List<UpiApp>> upiApps() async => const <UpiApp>[];

  @override
  Future<void> start({
    required String subscriptionId,
    required String sessionId,
    required String environment,
    required String upiPackage,
  }) async {}

  @override
  Stream<CashfreeResult> get results => _results.stream;

  @override
  Future<void> nextResume() async {}
}

void main() {
  test('CashfreePaymentGateway forwards the normalised install source', () async {
    final _RecordingBackend backend = _RecordingBackend();
    final CashfreePaymentGateway gateway = CashfreePaymentGateway(
      backend,
      installSource: 'FilmyFace', // mixed case on purpose
      platform: _FakePlatform(),
      callbackGrace: const Duration(milliseconds: 1),
      holdInterval: const Duration(milliseconds: 1),
    );

    await gateway.subscribe(
      const UpiApp(packageName: 'com.example.upi', name: 'UPI'),
    );

    expect(backend.createCalled, isTrue);
    expect(backend.passedSource, 'filmyface');
  });

  test('a null install source is forwarded as null', () async {
    final _RecordingBackend backend = _RecordingBackend();
    final CashfreePaymentGateway gateway = CashfreePaymentGateway(
      backend,
      platform: _FakePlatform(),
      callbackGrace: const Duration(milliseconds: 1),
      holdInterval: const Duration(milliseconds: 1),
    );

    await gateway.subscribe(
      const UpiApp(packageName: 'com.example.upi', name: 'UPI'),
    );

    expect(backend.passedSource, isNull);
  });
}
