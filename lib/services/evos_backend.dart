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

  /// Codes cannot be delivered to the number's country.
  countryNotSupported,

  /// Asked to start a subscription for someone who already has access.
  alreadySubscribed,
  server,
}

/// Carries no message from the server: those are written for developers and
/// can contain a phone number.
class BackendFailure implements Exception {
  const BackendFailure(this.kind, {this.code});

  final BackendError kind;

  /// The server's own short name for the failure, such as
  /// `cashfree_auth_failed`, when it sent one. Shown to the user under the
  /// message and sent to analytics, so a failure can be identified without
  /// the server's logs. Never a message, which could hold personal data.
  final String? code;

  @override
  String toString() => 'BackendFailure(${code ?? kind.name})';
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

  /// The public rows of `app_config`, as `key -> value`. When [installSource]
  /// names a source with an active `webview_sources` row, every non-null column
  /// of that row overrides the matching global key (name, logo, colour, every
  /// paywall field, the login carousel and `webview_url`); a null column, no
  /// row, or an unattributed source returns the global settings unchanged.
  Future<Map<String, String>> fetchConfig(String? installSource);

  Future<bool> hasActiveSubscription();

  /// [installSource] (the saved Play `utm_source`, or null) lets the server
  /// pick a per-source plan and price. It is only a selector: the amount
  /// charged is read on the server, never sent from here.
  Future<SubscriptionSession> createSubscription(String? installSource);

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
  Future<Map<String, String>> fetchConfig(String? installSource) =>
      _guard(() async {
        // Row-level security returns the public rows only, whatever is asked.
        final List<Map<String, dynamic>> rows =
            await _client.from('app_config').select('key, value');
        final Map<String, String> config = <String, String>{
          for (final Map<String, dynamic> row in rows)
            if (row['key'] is String && row['value'] is String)
              row['key'] as String: row['value'] as String,
        };
        final String? source = installSource?.trim().toLowerCase();
        // 'unknown' is the parser's word for an unattributed install.
        if (source != null && source.isNotEmpty && source != 'unknown') {
          await _applySourceOverrides(config, source);
        }
        return config;
      });

  /// Column names in `webview_sources` that are not settings to overlay: the
  /// primary key and the active flag. Everything else is a per-source override
  /// of the matching `app_config` key, so a column added later flows through
  /// here without a code change.
  static const Set<String> _sourceMetaColumns = <String>{'source', 'is_active'};

  /// Overlays the active `webview_sources` row for [source] onto [config]:
  /// every non-null column replaces the global `app_config` value of the same
  /// key (a NULL column inherits the global value; an empty string is a real
  /// override that hides that part of the screen).
  ///
  /// Best-effort: a missing table (migration not pushed yet), no row, or any
  /// error leaves the global settings in place. Per-source identity is an
  /// enhancement and must never cost the rest of the settings, so this is kept
  /// out of `_guard` and swallows its own errors.
  Future<void> _applySourceOverrides(
    Map<String, String> config,
    String source,
  ) async {
    try {
      final List<Map<String, dynamic>> matches = await _client
          .from('webview_sources')
          .select()
          .eq('source', source)
          // The RLS policy already hides inactive rows; this is a second guard
          // so a loosened policy could never serve a disabled partner's brand.
          .eq('is_active', true)
          .limit(1);
      if (matches.isEmpty) return;
      mergeSourceRow(config, matches.first);
    } catch (_) {
      // Keep the global settings.
    }
  }

  /// Overlays one `webview_sources` [row] onto [config] in place: every column
  /// that is not meta and not null replaces the global value of the same key.
  /// Pure (no I/O) so the merge rules can be tested without a client.
  ///
  /// RemoteConfig.fromRows parses everything from strings (bools as
  /// 'true'/'false', numbers as text), so a non-string column is stringified.
  /// A null column inherits the global value; an empty string is kept, because
  /// it is a deliberate override that hides that part of the screen.
  static void mergeSourceRow(
    Map<String, String> config,
    Map<String, dynamic> row,
  ) {
    for (final MapEntry<String, dynamic> entry in row.entries) {
      if (_sourceMetaColumns.contains(entry.key)) continue;
      final Object? value = entry.value;
      if (value == null) continue;
      config[entry.key] = value is String ? value : value.toString();
    }
  }

  @override
  Future<bool> hasActiveSubscription() => _guard(() async {
        await _ensureSession();
        final Object? active = await _client.rpc<Object?>(
          'has_active_subscription',
        );
        return active == true;
      });

  @override
  Future<SubscriptionSession> createSubscription(String? installSource) =>
      _guard(() async {
        await _ensureSession();
        final String? source = installSource?.trim().toLowerCase();
        final FunctionResponse response = await _client.functions.invoke(
          'create-cashfree-subscription',
          body: <String, Object?>{
            if (source != null && source.isNotEmpty && source != 'unknown')
              'install_source': source,
          },
        );
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
      throw BackendFailure(_classify(error, onRefused), code: _serverCode(error));
    }
  }

  /// The `code` an edge function put in its error body, if it is a plain
  /// short name.
  static String? _serverCode(Object error) {
    if (error is! FunctionException) return null;
    final Object? details = error.details;
    final Object? code = details is Map ? details['code'] : null;
    return code is String && RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(code)
        ? code
        : null;
  }

  static BackendError _classify(Object error, BackendError onRefused) {
    if (error is AuthRetryableFetchException) return BackendError.network;
    if (error is AuthException) {
      final String code = error.code ?? '';
      // Said by sms-hook, which passes it through Supabase Auth as its message.
      if (error.message.contains('sms_country_not_supported')) {
        return BackendError.countryNotSupported;
      }
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
  Future<Map<String, String>> fetchConfig(String? installSource) async =>
      throw _failure;

  @override
  Future<bool> hasActiveSubscription() async => throw _failure;

  @override
  Future<SubscriptionSession> createSubscription(String? installSource) async =>
      throw _failure;

  @override
  Future<bool> verifySubscription(String subscriptionId) async =>
      throw _failure;
}
