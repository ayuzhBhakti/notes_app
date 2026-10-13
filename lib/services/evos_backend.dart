import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:supabase/supabase.dart';

import 'onboarding_store.dart';

/// Why a call to the backend did not succeed. Deliberately few: each is
/// something the user is told differently, or analytics counts separately.
enum BackendError {
  /// The build was given no Supabase project.
  notConfigured,
  network,

  /// There is no phone sign-in, or the server no longer accepts it.
  signedOut,
  invalidPhone,
  tooManyRequests,

  /// The code is wrong or has expired. The server does not say which.
  wrongCode,

  /// Asked to start a subscription for someone who already has access.
  alreadySubscribed,
  server,
}

/// Carries no message from the server: those are written for developers and
/// can contain a phone number.
class BackendFailure implements Exception {
  const BackendFailure(this.kind);

  final BackendError kind;

  @override
  String toString() => 'BackendFailure(${kind.name})';
}

class SignInResult {
  const SignInResult({required this.userId, required this.isNewUser});

  final String userId;

  /// The number had no account until this code was verified.
  final bool isNewUser;
}

/// What the server hands back for one Cashfree mandate. The session id is
/// single-use and is all the Cashfree SDK needs: the Cashfree id and secret
/// never leave the server.
class SubscriptionSession {
  const SubscriptionSession({
    required this.subscriptionId,
    required this.sessionId,
    required this.environment,
    required this.authorizationAmount,
  });

  final String subscriptionId;
  final String sessionId;

  /// `sandbox` or `production`. Decided by the server, so a build cannot be
  /// pointed at the wrong one.
  final String environment;
  final double authorizationAmount;
}

/// Everything the deep-link interface asks of the server.
abstract class EvosBackend {
  /// True when a phone sign-in is saved on this device. Synchronous, and no
  /// proof the server still accepts it: the first call that needs it finds out.
  bool get isSignedIn;

  Future<void> sendOtp(String phoneE164);

  Future<SignInResult> verifyOtp(String phoneE164, String code);

  /// Never throws: the device is signed out whatever the server says.
  Future<void> signOut();

  /// The public rows of `app_config`, as `key -> value`.
  Future<Map<String, String>> fetchConfig();

  Future<bool> hasActiveSubscription();

  Future<SubscriptionSession> createSubscription();

  /// True once Cashfree reports the mandate authorised.
  Future<bool> verifySubscription(String subscriptionId);
}

/// The only file in the app that imports `supabase`.
///
/// The pure-Dart client is used rather than `supabase_flutter`, which would
/// add an auth deep-link plugin that competes with DeepLinkService for
/// incoming links. The price is that the session is kept by hand, in
/// [OnboardingStore].
class SupabaseEvosBackend implements EvosBackend {
  SupabaseEvosBackend(String url, String anonKey, this._store)
      : _client = SupabaseClient(
          url,
          anonKey,
          // PKCE is for browser redirects, which a code typed from an SMS
          // never goes through.
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        ) {
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (AuthState state) {
        final Session? session = state.session;
        if (session != null) {
          unawaited(_store.saveSession(jsonEncode(session.toJson())));
        } else if (state.event == AuthChangeEvent.signedOut) {
          unawaited(_store.clearSession());
        }
      },
      // The stream also carries refresh failures. They are handled where the
      // call that needed the session is made.
      onError: (Object _) {},
    );
  }

  final SupabaseClient _client;
  final OnboardingStore _store;
  late final StreamSubscription<AuthState> _authSubscription;

  static const Duration _timeout = Duration(seconds: 20);

  @override
  bool get isSignedIn => _store.loadSession() != null;

  @override
  Future<void> sendOtp(String phoneE164) => _guard(
        () => _client.auth.signInWithOtp(phone: phoneE164),
      );

  @override
  Future<SignInResult> verifyOtp(String phoneE164, String code) => _guard(
        () async {
          final AuthResponse response = await _client.auth.verifyOTP(
            phone: phoneE164,
            token: code,
            type: OtpType.sms,
          );
          final User? user = response.user;
          if (response.session == null || user == null) {
            throw const BackendFailure(BackendError.wrongCode);
          }
          final DateTime? created = DateTime.tryParse(user.createdAt);
          return SignInResult(
            userId: user.id,
            // The account is made by the first verified code, moments ago.
            isNewUser: created != null &&
                DateTime.now().toUtc().difference(created.toUtc()).inMinutes <
                    2,
          );
        },
        // Anything the server refuses here is, to the user, a code that
        // did not work.
        onRefused: BackendError.wrongCode,
      );

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(_timeout);
    } catch (_) {
      // Offline, or the session was already gone.
    }
    await _store.clearSession();
  }

  @override
  Future<Map<String, String>> fetchConfig() => _guard(() async {
        // Row-level security returns the public rows only, whatever is asked.
        final List<Map<String, dynamic>> rows =
            await _client.from('app_config').select('key, value');
        return <String, String>{
          for (final Map<String, dynamic> row in rows)
            if (row['key'] is String && row['value'] is String)
              row['key'] as String: row['value'] as String,
        };
      });

  @override
  Future<bool> hasActiveSubscription() => _guard(() async {
        await _ensureSession();
        final Object? active = await _client.rpc<Object?>(
          'has_active_subscription',
        );
        return active == true;
      });

  @override
  Future<SubscriptionSession> createSubscription() => _guard(() async {
        await _ensureSession();
        final FunctionResponse response =
            await _client.functions.invoke('create-cashfree-subscription');
        final Object? data = response.data;
        if (data is! Map) throw const BackendFailure(BackendError.server);
        final Object? subscriptionId = data['subscription_id'];
        final Object? sessionId = data['subscription_session_id'];
        if (subscriptionId is! String || sessionId is! String) {
          throw const BackendFailure(BackendError.server);
        }
        return SubscriptionSession(
          subscriptionId: subscriptionId,
          sessionId: sessionId,
          environment: data['environment'] as String? ?? 'sandbox',
          authorizationAmount:
              (data['authorization_amount'] as num?)?.toDouble() ?? 0,
        );
      });

  @override
  Future<bool> verifySubscription(String subscriptionId) => _guard(() async {
        await _ensureSession();
        final FunctionResponse response = await _client.functions.invoke(
          'verify-cashfree-subscription',
          body: <String, Object?>{'subscription_id': subscriptionId},
        );
        final Object? data = response.data;
        if (data is! Map) return false;
        return data['mandate_success'] == true || data['is_active'] == true;
      });

  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _client.dispose();
  }

  /// The client starts every launch signed out. This puts back the session
  /// saved by the last one, refreshing it if it has expired.
  Future<void> _ensureSession() async {
    if (_client.auth.currentSession != null) return;
    final String? saved = _store.loadSession();
    if (saved == null) throw const BackendFailure(BackendError.signedOut);
    try {
      await _client.auth.recoverSession(saved);
    } on AuthRetryableFetchException {
      // Offline. The saved session is kept for the next try.
      throw const BackendFailure(BackendError.network);
    } on AuthException {
      // The refresh token was refused: revoked, or the account is gone.
      await _store.clearSession();
      throw const BackendFailure(BackendError.signedOut);
    }
  }

  Future<T> _guard<T>(
    Future<T> Function() call, {
    BackendError onRefused = BackendError.server,
  }) async {
    try {
      return await call().timeout(_timeout);
    } on BackendFailure {
      rethrow;
    } catch (error) {
      if (kDebugMode) debugPrint('[evos] Backend call failed: $error');
      throw BackendFailure(_classify(error, onRefused));
    }
  }

  static BackendError _classify(Object error, BackendError onRefused) {
    if (error is AuthRetryableFetchException) return BackendError.network;
    if (error is AuthException) {
      final String code = error.code ?? '';
      if (error.statusCode == '429' || code.contains('rate_limit')) {
        return BackendError.tooManyRequests;
      }
      // Phone sign-in switched off, or the SMS could not be sent: the
      // project's fault, not something the user typed.
      if (code == 'phone_provider_disabled' ||
          code == 'sms_send_failed' ||
          code == 'hook_timeout' ||
          code == 'unexpected_failure') {
        return BackendError.server;
      }
      if (code == 'validation_failed') {
        return onRefused == BackendError.wrongCode
            ? BackendError.wrongCode
            : BackendError.invalidPhone;
      }
      // A server fault is never the user's code being wrong.
      final int status = int.tryParse(error.statusCode ?? '') ?? 0;
      return status >= 500 ? BackendError.server : onRefused;
    }
    if (error is FunctionException) {
      if (error.status == 409) return BackendError.alreadySubscribed;
      if (error.status == 401) return BackendError.signedOut;
      return BackendError.server;
    }
    if (error is PostgrestException) return BackendError.server;
    // What is left is the transport: no route, DNS, TLS, or a timeout.
    return BackendError.network;
  }
}

/// Used when the build was given no Supabase project.
///
/// A debug build carries on so the flow can be developed and tested without
/// credentials: any number is accepted and the code is [debugCode]. A release
/// build refuses, because a sign-in that checks nothing is worse than a
/// visible error.
class UnconfiguredEvosBackend implements EvosBackend {
  const UnconfiguredEvosBackend(this._store);

  final OnboardingStore _store;

  static const String debugCode = '123456';

  static const BackendFailure _failure =
      BackendFailure(BackendError.notConfigured);

  @override
  bool get isSignedIn => _store.loadSession() != null;

  @override
  Future<void> sendOtp(String phoneE164) async {
    if (!kDebugMode) throw _failure;
    debugPrint(
      '[evos] Supabase is switched off for this build, so NO SMS was sent.\n'
      '       The code is $debugCode.',
    );
  }

  @override
  Future<SignInResult> verifyOtp(String phoneE164, String code) async {
    if (!kDebugMode) throw _failure;
    if (code != debugCode) throw const BackendFailure(BackendError.wrongCode);
    await _store.saveSession('debug');
    return const SignInResult(userId: 'debug-user', isNewUser: false);
  }

  @override
  Future<void> signOut() => _store.clearSession();

  @override
  Future<Map<String, String>> fetchConfig() async => throw _failure;

  @override
  Future<bool> hasActiveSubscription() async => throw _failure;

  @override
  Future<SubscriptionSession> createSubscription() async => throw _failure;

  @override
  Future<bool> verifySubscription(String subscriptionId) async =>
      throw _failure;
}
