import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

/// A Play Store link starts onboarding when its `referrer` contains
/// `flow=onboarding`:
///
///   https://play.google.com/store/apps/details?id=com.spacewire.evos&referrer=flow%3Donboarding
///
/// The referrer is itself a query string, so it can carry campaign parameters
/// alongside: `referrer=utm_source%3Dmail%26flow%3Donboarding`.
const String kReferrerFlowKey = 'flow';
const String kReferrerOnboardingFlow = 'onboarding';

/// Launches on which an empty referrer is asked for again before it is taken
/// as final. On 2026-10-22 four Play installs through the onboarding link read
/// an empty referrer on their first launch; whether Play fills it in later is
/// not known, and asking again costs one quick call per launch.
const int kReferrerMaxAttempts = 5;

bool isOnboardingReferrer(String? referrer) {
  if (referrer == null || referrer.trim().isEmpty) return false;
  try {
    // Handed over still encoded ("flow%3Donboarding"), the whole string would
    // otherwise read as one key with no value.
    final String text =
        referrer.contains('=') ? referrer : Uri.decodeQueryComponent(referrer);
    return Uri.splitQueryString(text)[kReferrerFlowKey] ==
        kReferrerOnboardingFlow;
  } catch (_) {
    // A referrer is whatever the link's author typed. Malformed percent
    // encoding must not stop the app from starting.
    return false;
  }
}

/// Whether an answer from Play settles the referrer for this install. Play's
/// own answer for an install without a link is non-empty
/// (`utm_source=google-play&utm_medium=organic`), so an empty one is asked
/// for again, until [kReferrerMaxAttempts] launches have tried.
bool isReferrerFinal(String referrer, int attempt) =>
    referrer.trim().isNotEmpty || attempt >= kReferrerMaxAttempts;

/// Play's answer for this install.
class InstallReferrer {
  const InstallReferrer({
    required this.referrer,
    this.clickSeconds = 0,
    this.installBeginSeconds = 0,
  });

  /// The `referrer` parameter of the Play Store link, or Play's default.
  final String referrer;

  /// When the link was tapped, as Play recorded it. 0: Play recorded no tap.
  final int clickSeconds;

  /// When the install started, as Play recorded it. 0: unknown.
  final int installBeginSeconds;
}

/// Reads the referrer of the Play Store link that led to this install.
///
/// Backed by a method channel in MainActivity.kt over Google's Install
/// Referrer library, rather than a plugin.
class InstallReferrerService {
  const InstallReferrerService();

  static const MethodChannel _channel =
      MethodChannel('com.spacewire.evos/install_referrer');

  /// Null when Play could not be asked at all: not Android, no Play Store on
  /// the device, or no answer in time.
  Future<InstallReferrer?> fetch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      // Runs before the first frame, so it must not be allowed to hang.
      final Map<Object?, Object?>? answer = await _channel
          .invokeMethod<Map<Object?, Object?>>('getInstallReferrer')
          .timeout(const Duration(seconds: 3));
      if (answer == null) return null;
      final Object? referrer = answer['referrer'];
      final Object? click = answer['clickSeconds'];
      final Object? begin = answer['installBeginSeconds'];
      return InstallReferrer(
        referrer: referrer is String ? referrer : '',
        clickSeconds: click is int ? click : 0,
        installBeginSeconds: begin is int ? begin : 0,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[referrer] Could not read: $error');
      return null;
    }
  }
}
