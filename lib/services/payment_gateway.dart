import 'dart:async';

import 'package:flutter/services.dart';

import 'evos_backend.dart';

/// A UPI app installed on this phone that can approve an AutoPay mandate.
class UpiApp {
  const UpiApp({required this.packageName, required this.name});

  final String packageName;

  /// Shown to the user, and sent to analytics. Never the package name.
  final String name;
}

/// The user backed out of the UPI app. Never shown as an error.
class PaymentCanceled implements Exception {
  const PaymentCanceled();

  @override
  String toString() => 'PaymentCanceled';
}

enum PaymentError {
  /// The chosen UPI app is gone or cannot take a mandate.
  upiAppUnavailable,

  /// The UPI app or the bank refused.
  declined,

  /// The UPI app reported back, but Cashfree has not confirmed the mandate
  /// in the time the app waits. Money may have moved.
  pending,

  /// Payments are not available on this platform.
  unsupported,
}

class PaymentFailure implements Exception {
  const PaymentFailure(this.kind, {this.code});

  final PaymentError kind;

  /// Cashfree's own short code for a refusal, for analytics.
  final String? code;

  @override
  String toString() => 'PaymentFailure(${code ?? kind.name})';
}

/// The seam between the paywall and whoever takes the money. The screens know
/// only this interface.
abstract class PaymentGateway {
  /// True when no real payment is taken. The paywall says so on screen.
  bool get isSimulated;

  /// In the order they should be offered; the first is preselected.
  Future<List<UpiApp>> upiApps();

  /// Starts the subscription through [app]. Completes once the server has
  /// confirmed the mandate, throws [PaymentCanceled] if the user backs out,
  /// and throws [PaymentFailure] or [BackendFailure] otherwise.
  Future<void> subscribe(UpiApp app);
}

/// Stands in when the build has no backend. Every purchase succeeds, nothing
/// is charged, and nothing is verified.
class SimulatedPaymentGateway implements PaymentGateway {
  const SimulatedPaymentGateway({
    this.delay = const Duration(milliseconds: 1200),
  });

  /// Long enough for the paywall's busy state to be visible.
  final Duration delay;

  @override
  bool get isSimulated => true;

  @override
  Future<List<UpiApp>> upiApps() async => const <UpiApp>[
        UpiApp(packageName: 'simulated', name: 'Test UPI app'),
      ];

  @override
  Future<void> subscribe(UpiApp app) => Future<void>.delayed(delay);
}

/// Cashfree UPI AutoPay, the same flow as CashAlert:
///
/// 1. the server creates the subscription and returns a session id,
/// 2. the Cashfree SDK opens the chosen UPI app to approve the mandate,
/// 3. the server is asked until Cashfree confirms it.
///
/// The SDK is used from Kotlin over a method channel, handled in
/// `android/.../payments/PaymentsChannel.kt`. Android only.
class CashfreePaymentGateway implements PaymentGateway {
  const CashfreePaymentGateway(
    this._backend, {
    this.verifyAttempts = 12,
    this.verifyInterval = const Duration(seconds: 2),
  });

  final EvosBackend _backend;

  /// Cashfree usually confirms within a few seconds of the UPI app closing.
  final int verifyAttempts;
  final Duration verifyInterval;

  static const MethodChannel _channel = MethodChannel(
    'com.spacewire.evos/payments',
  );

  @override
  bool get isSimulated => false;

  @override
  Future<List<UpiApp>> upiApps() async {
    try {
      final List<Map<Object?, Object?>>? apps =
          await _channel.invokeListMethod<Map<Object?, Object?>>('upiApps');
      return <UpiApp>[
        for (final Map<Object?, Object?> app
            in apps ?? const <Map<Object?, Object?>>[])
          UpiApp(
            packageName: app['package']! as String,
            name: app['name']! as String,
          ),
      ];
    } on MissingPluginException {
      return const <UpiApp>[];
    }
  }

  @override
  Future<void> subscribe(UpiApp app) async {
    final SubscriptionSession session = await _backend.createSubscription();
    try {
      await _channel.invokeMethod<void>('startSubscription', <String, Object?>{
        'subscriptionId': session.subscriptionId,
        'sessionId': session.sessionId,
        'environment': session.environment,
        'upiPackage': app.packageName,
      });
    } on PlatformException catch (error) {
      throw switch (error.code) {
        'cancelled' => const PaymentCanceled(),
        'upi_app_unavailable' =>
          const PaymentFailure(PaymentError.upiAppUnavailable),
        // `details` is Cashfree's code, never its message.
        _ => PaymentFailure(
            PaymentError.declined,
            code: error.details as String?,
          ),
      };
    } on MissingPluginException {
      throw const PaymentFailure(PaymentError.unsupported);
    }

    for (int attempt = 0; attempt < verifyAttempts; attempt++) {
      if (await _backend.verifySubscription(session.subscriptionId)) return;
      if (attempt < verifyAttempts - 1) {
        await Future<void>.delayed(verifyInterval);
      }
    }
    throw const PaymentFailure(PaymentError.pending);
  }
}
