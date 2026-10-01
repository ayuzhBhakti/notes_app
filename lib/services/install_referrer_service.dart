import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

/// A Play Store link starts onboarding when its `referrer` contains
/// `flow=onboarding`:
///
///   https://play.google.com/store/apps/details?id=com.spacewire.notes&referrer=flow%3Donboarding
///
/// The referrer is itself a query string, so it can carry campaign parameters
/// alongside: `referrer=utm_source%3Dmail%26flow%3Donboarding`.
const String kReferrerFlowKey = 'flow';
const String kReferrerOnboardingFlow = 'onboarding';

bool isOnboardingReferrer(String? referrer) {
  if (referrer == null || referrer.isEmpty) return false;
  try {
    return Uri.splitQueryString(referrer)[kReferrerFlowKey] ==
        kReferrerOnboardingFlow;
  } catch (_) {
    // A referrer is whatever the link's author typed. Malformed percent
    // encoding must not stop the app from starting.
    return false;
  }
}

/// Reads the referrer of the Play Store link that led to this install.
///
/// Backed by a method channel in MainActivity.kt over Google's Install
/// Referrer library, rather than a plugin.
class InstallReferrerService {
  const InstallReferrerService();

  static const MethodChannel _channel =
      MethodChannel('com.spacewire.notes/install_referrer');

  /// The referrer string, which is empty or Play's own default for an install
  /// that did not come from a link. Null when it could not be read at all:
  /// not Android, no Play Store on the device, or no answer in time.
  Future<String?> fetch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      // Runs before the first frame, so it must not be allowed to hang.
      return await _channel
          .invokeMethod<String>('getInstallReferrer')
          .timeout(const Duration(seconds: 3));
    } catch (error) {
      if (kDebugMode) debugPrint('[referrer] Could not read: $error');
      return null;
    }
  }
}
