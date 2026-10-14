import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding.dart';

/// The only file in the app that imports `shared_preferences`.
///
/// The onboarding stage is device-local so the first frame is already the
/// right interface, before any network call. Whether the user has paid is
/// not decided here: the server is asked, and the stage follows its answer.
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

  static const String _sessionKey = 'evos_session_v1';

  /// The phone sign-in, as the JSON the Supabase client hands out. Lives here
  /// because the pure-Dart client keeps a session in memory only.
  String? loadSession() => _prefs.getString(_sessionKey);

  Future<void> saveSession(String session) =>
      _prefs.setString(_sessionKey, session);

  Future<void> clearSession() => _prefs.remove(_sessionKey);

  static const String _configKey = 'evos_config_v1';

  /// The backend's settings as last fetched. See `decodeConfigRows`.
  String? loadConfig() => _prefs.getString(_configKey);

  Future<void> saveConfig(String config) => _prefs.setString(_configKey, config);

  static const String _referrerCheckedKey = 'install_referrer_checked';

  /// The install referrer never changes after install, so it is read once.
  /// The only way back to the notes app is clearing the app's data, which
  /// clears this too, so the referrer is read again on the next launch.
  bool get installReferrerChecked =>
      _prefs.getBool(_referrerCheckedKey) ?? false;

  Future<void> markInstallReferrerChecked() =>
      _prefs.setBool(_referrerCheckedKey, true);
}
