import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'evos_backend.dart';

/// A UPI app installed on this phone that can approve an AutoPay mandate.
class UpiApp {
  const UpiApp({required this.packageName, required this.name});

  final String packageName;

  /// Shown to the user, and sent to analytics. Never the package name.
  final String name;
}

/// The user backed out of the UPI app, or left the processing screen. Never
/// shown as an error.
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

  /// Cashfree has not confirmed the mandate in the time the screen waits.
  /// Money may have moved: the gateway keeps checking ([PaymentGateway.checkLastAttempt]).
  pending,

  /// The server did not answer in time while preparing the payment.
  slowNetwork,

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

/// What the paywall's processing screen says while a payment is under way;
/// [idle] when it is closed.
enum CheckoutStage { idle, preparing, openingApp, confirming }

/// The seam between the paywall and whoever takes the money. The screens know
/// only this interface.
abstract class PaymentGateway {
  /// True when no real payment is taken. The paywall says so on screen.
  bool get isSimulated;

  /// In the order they should be offered; the first is preselected.
  Future<List<UpiApp>> upiApps();

  /// One tap on Try Now. Completes once the server has confirmed the mandate;
  /// throws [PaymentCanceled] if the user backs out or calls [leave], and
  /// [PaymentFailure] or [BackendFailure] otherwise. [onStage] reports what
  /// the processing screen should say. Never waits more than a few seconds for
  /// the server, so the screen cannot stay stuck.
  Future<void> subscribe(
    UpiApp app, {
    void Function(CheckoutStage stage)? onStage,
  });

  /// Back on the processing screen: [subscribe] stops waiting and throws
  /// [PaymentCanceled]. A payment already in the UPI app keeps going.
  void leave();

  /// Keeps asking about the last attempt for a minute, without blocking any
  /// screen; true once Cashfree confirms it. Cashfree's answer on the phone is
  /// not final, and the bank may still approve. A new [subscribe] makes this
  /// return false.
  Future<bool> checkLastAttempt();
}

/// Stands in when the build has no backend. Every purchase succeeds, nothing
/// is charged, and nothing is verified.
class SimulatedPaymentGateway implements PaymentGateway {
  const SimulatedPaymentGateway({
    this.delay = const Duration(milliseconds: 1200),
  });

  /// Long enough for the processing screen to be seen.
  final Duration delay;

  @override
  bool get isSimulated => true;

  @override
  Future<List<UpiApp>> upiApps() async => const <UpiApp>[
        UpiApp(packageName: 'simulated', name: 'Test UPI app'),
      ];

  @override
  Future<void> subscribe(
    UpiApp app, {
    void Function(CheckoutStage stage)? onStage,
  }) async {
    onStage?.call(CheckoutStage.preparing);
    await Future<void>.delayed(delay ~/ 2);
    onStage?.call(CheckoutStage.confirming);
    await Future<void>.delayed(delay ~/ 2);
  }

  @override
  void leave() {}

  @override
  Future<bool> checkLastAttempt() async => false;
}

/// What the Cashfree SDK said when the UPI app handed back.
class CashfreeResult {
  const CashfreeResult({
    required this.subscriptionId,
    required this.ok,
    this.code,
  });

  final String? subscriptionId;

  /// True for Cashfree's "verify" callback: the UPI app reported back, and
  /// only the server can say whether the mandate really went through.
  final bool ok;

  /// Cashfree's code for a failure (`action_cancelled` when backed out).
  final String? code;
}

/// The parts of the phone the gateway needs, behind a seam tests replace.
abstract class PaymentsPlatform {
  Future<List<UpiApp>> upiApps();

  /// Opens [upiPackage] through the Cashfree SDK. Returns once it is opened;
  /// the outcome arrives on [results].
  Future<void> start({
    required String subscriptionId,
    required String sessionId,
    required String environment,
    required String upiPackage,
  });

  /// Cashfree's callbacks, as they arrive.
  Stream<CashfreeResult> get results;

  /// Completes the next time the app comes back to the front.
  Future<void> nextResume();
}

/// The method channel handled by `android/.../payments/PaymentsChannel.kt`.
class MethodChannelPaymentsPlatform implements PaymentsPlatform {
  MethodChannelPaymentsPlatform() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'cashfreeResult') return;
      final Map<Object?, Object?> args =
          call.arguments as Map<Object?, Object?>;
      _results.add(CashfreeResult(
        subscriptionId: args['subscriptionId'] as String?,
        ok: args['ok'] == true,
        code: args['code'] as String?,
      ));
    });
  }

  static const MethodChannel _channel = MethodChannel(
    'com.spacewire.evos/payments',
  );

  final StreamController<CashfreeResult> _results =
      StreamController<CashfreeResult>.broadcast();

  @override
  Stream<CashfreeResult> get results => _results.stream;

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
  Future<void> start({
    required String subscriptionId,
    required String sessionId,
    required String environment,
    required String upiPackage,
  }) =>
      _channel.invokeMethod<void>('startSubscription', <String, Object?>{
        'subscriptionId': subscriptionId,
        'sessionId': sessionId,
        'environment': environment,
        'upiPackage': upiPackage,
      });

  @override
  Future<void> nextResume() {
    final Completer<void> resumed = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(onResume: () {
      listener.dispose();
      if (!resumed.isCompleted) resumed.complete();
    });
    return resumed.future;
  }
}

/// Cashfree UPI AutoPay, the same flow as CashAlert's PaywallActivity:
///
/// 1. the server creates the subscription (at most [holdLimit]),
/// 2. the Cashfree SDK opens the chosen UPI app,
/// 3. Cashfree calls back when the user returns; if it has not within
///    [callbackGrace] of the app coming back, the server is asked anyway,
/// 4. the server is asked every [holdInterval] for at most [holdLimit],
/// 5. an unconfirmed attempt is checked for [backgroundLimit] more, without
///    holding the screen ([checkLastAttempt]).
///
/// Before this (2026-10-22), the SDK call was held open until Cashfree called
/// back, and Cashfree does not always call back when the user returns without
/// paying — so coming back from the UPI app could leave the paywall loading
/// for a long time, with no way out. Now [startSubscription] returns as soon
/// as the UPI app opens, the callback arrives separately, and every wait is
/// capped; [leave] lets the user stop waiting.
class CashfreePaymentGateway implements PaymentGateway {
  CashfreePaymentGateway(
    this._backend, {
    PaymentsPlatform? platform,
    this.holdLimit = const Duration(seconds: 6),
    this.holdInterval = const Duration(seconds: 1),
    this.backgroundLimit = const Duration(seconds: 60),
    this.backgroundInterval = const Duration(seconds: 3),
    this.callbackGrace = const Duration(milliseconds: 1500),
  }) : _platform = platform ?? MethodChannelPaymentsPlatform();

  final EvosBackend _backend;
  final PaymentsPlatform _platform;

  /// The longest the processing screen holds the user, per wait.
  final Duration holdLimit;
  final Duration holdInterval;
  final Duration backgroundLimit;
  final Duration backgroundInterval;
  final Duration callbackGrace;

  /// Each Try Now is a new attempt with its own subscription id; answers about
  /// any other id are ignored.
  String? _lastSubscriptionId;
  int _attempt = 0;
  Completer<void>? _left;

  @override
  bool get isSimulated => false;

  @override
  Future<List<UpiApp>> upiApps() => _platform.upiApps();

  @override
  void leave() {
    final Completer<void>? left = _left;
    if (left != null && !left.isCompleted) left.complete();
  }

  @override
  Future<void> subscribe(
    UpiApp app, {
    void Function(CheckoutStage stage)? onStage,
  }) async {
    final int attempt = ++_attempt;
    _lastSubscriptionId = null;
    final Completer<void> left = Completer<void>();
    _left = left;

    /// [work], unless the user leaves the processing screen first. Both
    /// branches are consumed, so a late winner never becomes an unhandled
    /// async error.
    Future<T> unlessLeft<T>(Future<T> work) {
      final Completer<T> out = Completer<T>();
      work.then(
        (T value) {
          if (!out.isCompleted) out.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!out.isCompleted) out.completeError(error, stack);
        },
      );
      left.future.then((_) {
        if (!out.isCompleted) out.completeError(const PaymentCanceled());
      });
      return out.future;
    }

    onStage?.call(CheckoutStage.preparing);
    final SubscriptionSession session;
    try {
      session =
          await unlessLeft(_backend.createSubscription().timeout(holdLimit));
    } on TimeoutException {
      throw const PaymentFailure(PaymentError.slowNetwork);
    }
    if (attempt != _attempt) throw const PaymentCanceled();
    _lastSubscriptionId = session.subscriptionId;

    // Listening before the UPI app opens, so no callback can be missed.
    final Future<CashfreeResult> callback = _platform.results
        .where((CashfreeResult r) =>
            r.subscriptionId == null ||
            r.subscriptionId == session.subscriptionId)
        .first;
    final Future<void> resumed = _platform.nextResume();

    onStage?.call(CheckoutStage.openingApp);
    try {
      await unlessLeft(_platform.start(
        subscriptionId: session.subscriptionId,
        sessionId: session.sessionId,
        environment: session.environment,
        upiPackage: app.packageName,
      ));
    } on PlatformException catch (error) {
      throw error.code == 'upi_app_unavailable'
          ? const PaymentFailure(PaymentError.upiAppUnavailable)
          : PaymentFailure(PaymentError.declined, code: error.details as String?);
    } on MissingPluginException {
      throw const PaymentFailure(PaymentError.unsupported);
    }

    // Cashfree normally calls back when the user returns from the UPI app. If
    // it does not within the grace after the app comes back, confirm anyway,
    // so Try Now can never stay stuck.
    final CashfreeResult? result =
        await unlessLeft(Future.any(<Future<CashfreeResult?>>[
      callback,
      resumed.then((_) =>
          Future<CashfreeResult?>.delayed(callbackGrace, () => null)),
    ]));
    if (result != null && !result.ok) {
      throw result.code == _cancelledCode
          ? const PaymentCanceled()
          : PaymentFailure(PaymentError.declined, code: result.code);
    }

    onStage?.call(CheckoutStage.confirming);
    final bool confirmed = await unlessLeft(
      _awaitConfirmed(session.subscriptionId, holdLimit, holdInterval),
    );
    if (!confirmed) throw const PaymentFailure(PaymentError.pending);
  }

  @override
  Future<bool> checkLastAttempt() async {
    final String? id = _lastSubscriptionId;
    final int attempt = _attempt;
    if (id == null) return false;
    final bool confirmed = await _awaitConfirmed(
      id,
      backgroundLimit,
      backgroundInterval,
      stillWanted: () => attempt == _attempt,
    );
    return confirmed && attempt == _attempt;
  }

  /// Asks the server until it confirms the mandate or [limit] passes. A failed
  /// or slow question counts as "not yet".
  Future<bool> _awaitConfirmed(
    String id,
    Duration limit,
    Duration interval, {
    bool Function()? stillWanted,
  }) async {
    final Stopwatch clock = Stopwatch()..start();
    while (stillWanted?.call() ?? true) {
      final Duration left = limit - clock.elapsed;
      if (left <= Duration.zero) break;
      bool confirmed;
      try {
        confirmed = await _backend.verifySubscription(id).timeout(left);
      } catch (_) {
        confirmed = false;
      }
      if (confirmed) return true;
      if (clock.elapsed + interval >= limit) break;
      await Future<void>.delayed(interval);
    }
    return false;
  }

  static const String _cancelledCode = 'action_cancelled';
}
