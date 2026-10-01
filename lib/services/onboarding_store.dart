import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding.dart';

/// The only file in the app that imports `shared_preferences`.
///
/// Onboarding state is device-local because the flow runs before sign-in, so
/// there is no uid to store it under in Firestore.
class OnboardingStore {
  const OnboardingStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'onboarding_v1';

  /// Awaited once in `main()` before `runApp`.
  static Future<OnboardingStore> open() async =>
      OnboardingStore(await SharedPreferences.getInstance());

  /// Synchronous: SharedPreferences is fully loaded before `runApp`, which is
  /// what lets the first frame already be the right interface.
  OnboardingState load() => OnboardingState.decode(_prefs.getString(_key));

  Future<void> save(OnboardingState state) =>
      _prefs.setString(_key, state.encode());

  Future<void> clear() => _prefs.remove(_key);

  static const String _referrerCheckedKey = 'install_referrer_checked';

  /// The install referrer never changes after install, so it is read once.
  /// Kept apart from [clear] on purpose: after a debug reset, re-reading the
  /// same referrer would put the device straight back into onboarding.
  bool get installReferrerChecked =>
      _prefs.getBool(_referrerCheckedKey) ?? false;

  Future<void> markInstallReferrerChecked() =>
      _prefs.setBool(_referrerCheckedKey, true);
}
