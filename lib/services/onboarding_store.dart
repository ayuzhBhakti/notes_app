import 'package:shared_preferences/shared_preferences.dart';

import '../models/attribution.dart';
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

  static const String _notesKey = 'local_notes_v1';

  /// The store-review account's notes, as JSON. That account has no Firebase
  /// identity, so its notes live only on the device. See `LocalNotesStore`.
  String? loadNotes() => _prefs.getString(_notesKey);

  Future<void> saveNotes(String notes) => _prefs.setString(_notesKey, notes);

  static const String _referrerCheckedKey = 'install_referrer_checked';

  /// The install referrer never changes after install, so it is read once.
  /// The only way back to the notes app is clearing the app's data, which
  /// clears this too, so the referrer is read again on the next launch.
  bool get installReferrerChecked =>
      _prefs.getBool(_referrerCheckedKey) ?? false;

  Future<void> markInstallReferrerChecked() =>
      _prefs.setBool(_referrerCheckedKey, true);

  static const String _referrerAttemptsKey = 'install_referrer_attempts';

  /// Launches that have asked Play and got an empty referrer. See
  /// `isReferrerFinal`.
  int get installReferrerAttempts => _prefs.getInt(_referrerAttemptsKey) ?? 0;

  Future<void> saveInstallReferrerAttempts(int attempts) =>
      _prefs.setInt(_referrerAttemptsKey, attempts);

  static const String _installSourceKey = 'install_source_v1';

  /// The install's attributed source (the referrer's `utm_source`, lowercased),
  /// saved on the launch that read the referrer so it survives to the web-page
  /// step many launches later. Null when nothing attributable is known. Picks
  /// the per-source web page; see `webview_sources` and `fetchConfig`.
  String? get installSource => _prefs.getString(_installSourceKey);

  Future<void> saveInstallSource(String source) =>
      _prefs.setString(_installSourceKey, source);

  // ---- Attribution (see AttributionService) ----

  static const String _latestAttributionKey = 'attribution_latest_v1';
  static const String _firstAttributionKey = 'attribution_first_v1';
  static const String _syncedAttributionKey = 'attribution_synced_v1';
  static const String _installAttributedKey = 'attribution_install_here_v1';
  static const String _metaSettledKey = 'meta_referrer_settled_v1';
  static const String _metaAttemptsKey = 'meta_referrer_attempts_v1';

  /// The latest ad (last touch): what every event and the profile carry.
  Attribution? get latestAttribution =>
      Attribution.decode(_prefs.getString(_latestAttributionKey));

  Future<void> saveLatestAttribution(Attribution attribution) =>
      _prefs.setString(_latestAttributionKey, attribution.encode());

  /// The first ad this install ever had (first touch).
  Attribution? get firstAttribution =>
      Attribution.decode(_prefs.getString(_firstAttributionKey));

  Future<void> saveFirstAttribution(Attribution attribution) =>
      _prefs.setString(_firstAttributionKey, attribution.encode());

  /// The encoded attribution last saved on the server, so it is sent again
  /// only when it changes or the last try failed.
  String? get syncedAttribution => _prefs.getString(_syncedAttributionKey);

  Future<void> saveSyncedAttribution(String encoded) =>
      _prefs.setString(_syncedAttributionKey, encoded);

  /// True when this install's `Install Attributed` was sent by a version with
  /// this code; false for an install made by an older version and updated.
  bool get installAttributedHere =>
      _prefs.getBool(_installAttributedKey) ?? false;

  Future<void> markInstallAttributedHere() =>
      _prefs.setBool(_installAttributedKey, true);

  /// The Meta ad decode is finished for this install: decoded, refused, not
  /// a Meta ad, or out of attempts.
  bool get metaReferrerSettled => _prefs.getBool(_metaSettledKey) ?? false;

  Future<void> settleMetaReferrer() => _prefs.setBool(_metaSettledKey, true);

  /// Launches that asked the backend (or Play) and got no answer.
  int get metaReferrerAttempts => _prefs.getInt(_metaAttemptsKey) ?? 0;

  Future<void> saveMetaReferrerAttempts(int attempts) =>
      _prefs.setInt(_metaAttemptsKey, attempts);
}
