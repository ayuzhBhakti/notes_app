import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

import '../models/install_source.dart';

/// Carries analytics calls to the native SDKs. The seam tests replace to see
/// what would have been sent.
abstract class AnalyticsClient {
  /// Fire and forget: nothing in the app waits for analytics.
  void send(String method, [Map<String, Object?> arguments]);
}

/// Mixpanel and the Facebook (Meta) SDK, reached over a method channel handled
/// in `android/.../analytics/AnalyticsChannel.kt`, rather than through two
/// plugins. Android only: on iOS every call is dropped.
///
/// The keys are in `android/app/src/main/res/values/analytics_keys.xml`.
/// While a key is still its placeholder, that SDK is never started and its
/// calls are answered "not sent".
class MethodChannelAnalyticsClient implements AnalyticsClient {
  const MethodChannelAnalyticsClient();

  static const MethodChannel _channel = MethodChannel(
    'com.spacewire.evos/analytics',
  );

  @override
  void send(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(_send(method, arguments));
  }

  Future<void> _send(String method, Map<String, Object?> arguments) async {
    try {
      final bool? sent = await _channel.invokeMethod<bool>(method, arguments);
      if (kDebugMode) {
        debugPrint(
          '[analytics] $method $arguments'
          '${sent ?? false ? '' : ' (NOT sent: the SDK has no key)'}',
        );
      }
    } catch (_) {
      // Analytics must never break the app. This is also the path every
      // widget test takes, where nothing answers the channel.
    }
  }
}

/// Every analytics event the app sends, one method each, so the full list is
/// in one file. Described for people in docs/10-analytics.md; change both
/// together.
///
/// Mixpanel event names are Title Case and property names snake_case. No
/// event carries note content, a phone number or a sign-in code.
class Analytics {
  const Analytics(this._client);

  final AnalyticsClient _client;

  // ---- Install and links ----

  /// Once per install, when Google Play has said where it came from. Also
  /// puts the source on every later event and on the person's profile.
  ///
  /// [referrer] is Play's answer exactly as received, cut to 100 characters:
  /// link parameters only, and the one way to see what Play really sent.
  /// [clickRecorded] is false when Play recorded no tap on a link. [attempt]
  /// counts the launches that have asked, from 1; an empty answer is asked
  /// for again, so one install can send this more than once.
  void installAttributed(
    InstallSource source, {
    required String referrer,
    required bool clickRecorded,
    required int attempt,
  }) {
    final Map<String, Object> properties = source.toProperties();
    _client.send('setInstallSource', <String, Object?>{
      'properties': properties,
    });
    _track('Install Attributed', <String, Object>{
      ...properties,
      'install_referrer_raw': referrer.length > 100
          ? referrer.substring(0, 100)
          : referrer,
      'referrer_click_recorded': clickRecorded,
      'referrer_attempt': attempt,
    });
  }

  /// An onboarding link reached the app. [afterInstall]: it was a Play Store
  /// link followed before the app was installed. For attribution only: since
  /// 2026-10-22 every user signs in by phone, link or not.
  void deepLinkOpened({required bool afterInstall}) =>
      _track('Deep Link Opened', <String, Object>{
        'target': 'onboarding',
        'after_install': afterInstall,
      });

  void appOpened() => _track('App Opened');

  // ---- Sign-out ----

  /// Tracked before the reset, so the event still belongs to the person who
  /// signed out; the next person on this phone then starts clean.
  void signedOut() {
    _track('Signed Out');
    _client.send('reset');
  }

  // ---- Notes ----

  void notesListViewed() => _track('Notes List Viewed');

  void noteEditorOpened({required bool isNew}) =>
      _track('Note Editor Opened', <String, Object>{'is_new': isNew});

  void noteCreated() => _track('Note Created');

  void noteUpdated() => _track('Note Updated');

  void noteDeleted() => _track('Note Deleted');

  void noteRestored() => _track('Note Restored');

  /// [action] is `create`, `update`, `delete` or `restore`.
  void noteActionFailed(String action, String reason) => _track(
    'Note Action Failed',
    <String, Object>{'action': action, 'reason': reason},
  );

  void profileViewed() => _track('Profile Viewed');

  // ---- Onboarding ----

  void phoneEntryViewed() => _track('Phone Entry Viewed');

  /// A sign-in code was asked for. [resend]: from the code screen.
  /// [country]: ISO code of the number's country, such as `IN`; never the
  /// number itself.
  void otpRequested({required bool resend, required String country}) =>
      _track('OTP Requested', <String, Object>{
        'resend': resend,
        'country': country,
      });

  void otpRequestFailed(String reason) =>
      _track('OTP Request Failed', <String, Object>{'reason': reason});

  /// Ties this device's events to the account, by its server id. The phone
  /// number itself is never sent.
  void otpVerified({required String userId, required bool newUser}) {
    _client.send('identify', <String, Object?>{'id': userId});
    _track('OTP Verified', <String, Object>{'new_user': newUser});
    // Meta counts registrations, not logins.
    if (newUser) _metaCompleteRegistration('phone');
  }

  void otpVerifyFailed(String reason) =>
      _track('OTP Verify Failed', <String, Object>{'reason': reason});

  /// The store-review number signed in. No `identify`: it has no server
  /// account, and every reviewer shares it.
  void reviewAccountSignedIn() => _track('Review Account Signed In');

  void paywallViewed() => _track('Paywall Viewed');

  /// [upiApp] is the app's public name, such as "PhonePe".
  void upiAppSelected(String upiApp) =>
      _track('UPI App Selected', <String, Object>{'upi_app': upiApp});

  void checkoutStarted({
    required String planId,
    required double amount,
    required String currency,
    required String upiApp,
  }) {
    _track('Checkout Started', <String, Object>{
      'plan_id': planId,
      'upi_app': upiApp,
    });
    _client.send('metaInitiateCheckout', <String, Object?>{
      'plan_id': planId,
      'amount': amount,
      'currency': currency,
    });
  }

  /// [amount] is what was authorised today, the trial price. [simulated] is
  /// on the Mixpanel event so test-mode purchases can be filtered out. Meta
  /// is told about real purchases only: its Purchase event carries revenue
  /// that ad delivery is optimised on, and a simulated payment is not revenue.
  void subscriptionSucceeded({
    required String planId,
    required double amount,
    required String currency,
    required bool simulated,
  }) {
    _track('Subscription Succeeded', <String, Object>{
      'plan_id': planId,
      'amount': amount,
      'currency': currency,
      'simulated': simulated,
    });
    if (simulated) return;
    _client.send('metaSubscribe', <String, Object?>{
      'plan_id': planId,
      'amount': amount,
      'currency': currency,
    });
  }

  void checkoutCancelled(String planId) =>
      _track('Checkout Cancelled', <String, Object>{'plan_id': planId});

  void checkoutFailed(String planId, String reason) => _track(
    'Checkout Failed',
    <String, Object>{'plan_id': planId, 'reason': reason},
  );

  /// The subscriber's web page was shown. [hasUrl] is false when the backend
  /// has no `webview_url`, and a "come back soon" screen showed instead.
  /// The web page screen opened. [source] is the install's attributed source
  /// and [webHost] the host of the page actually loaded (never the full URL):
  /// together they make a misrouted source — landing on the wrong page, or on
  /// none — visible in Mixpanel instead of failing silently.
  void webPageViewed({
    required bool hasUrl,
    String? source,
    String? webHost,
  }) =>
      _track('Web Page Viewed', <String, Object>{
        'has_url': hasUrl,
        if (source != null && source.isNotEmpty) 'install_source': source,
        if (webHost != null && webHost.isNotEmpty) 'web_host': webHost,
      });

  /// The web page's main document failed to load. [reason] is the WebView's
  /// error type, such as `hostLookup`; never the URL or a message.
  void webPageFailed(String reason) =>
      _track('Web Page Failed', <String, Object>{'reason': reason});

  // ----

  void _track(
    String event, [
    Map<String, Object> properties = const <String, Object>{},
  ]) => _client.send('track', <String, Object?>{
    'event': event,
    'properties': properties,
  });

  void _metaCompleteRegistration(String method) => _client.send(
    'metaCompleteRegistration',
    <String, Object?>{'method': method},
  );
}
