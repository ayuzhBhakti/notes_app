/// Where an install came from, as carried by a tracked Play Store link
/// (`...&referrer=utm_source%3Dwhatsapp%26utm_campaign%3Ddiwali`) and handed to
/// the app by Google Play on first launch. Fields the link did not set are
/// null.
///
/// Analytics only. Whether the install starts onboarding is decided separately
/// by `isOnboardingReferrer`, from the `flow` key of the same string.
class InstallSource {
  const InstallSource({
    required this.source,
    required this.medium,
    this.campaign,
    this.content,
    this.term,
    this.fromGoogleAds = false,
  });

  static const String sourcePlay = 'google-play';
  static const String sourceGoogleAds = 'google-ads';
  static const String sourceUnknown = 'unknown';
  static const String mediumOrganic = 'organic';
  static const String mediumPaid = 'cpc';
  static const String mediumLink = 'link';

  /// Long enough for any real campaign name, short enough that a junk link
  /// cannot bloat every event.
  static const int _maxValueLength = 100;
  static const Set<String> _unset = <String>{'', '(not set)', 'not set'};

  final String source;
  final String medium;
  final String? campaign;
  final String? content;
  final String? term;

  /// The install followed a Google Ads click. The click id itself is not kept.
  final bool fromGoogleAds;

  /// An install nobody's link can take credit for: found in the store, or not
  /// from Play at all.
  bool get isOrganic => medium == mediumOrganic && !fromGoogleAds;

  /// As sent to Mixpanel. Only what the link set is included: an absent
  /// campaign is absent, not an empty string.
  Map<String, Object> toProperties() => <String, Object>{
    'install_source': source,
    'install_medium': medium,
    'install_organic': isOrganic,
    'install_campaign': ?campaign,
    'install_content': ?content,
    'install_term': ?term,
  };

  /// Never fails: an empty, missing or unreadable referrer is an organic
  /// install from an unknown source. Play itself reports a store search as
  /// `utm_source=google-play&utm_medium=organic`.
  static InstallSource parse(String? referrer) {
    final Map<String, String> values = _pairs(referrer);
    final bool fromAds = values['gclid'] != null;
    final String? source = values['utm_source'];
    final String medium;
    if (values['utm_medium'] != null) {
      medium = values['utm_medium']!;
    } else if (fromAds) {
      medium = mediumPaid;
    } else if (source != null && source != sourcePlay) {
      // A link that names its source but no medium is still somebody's link.
      medium = mediumLink;
    } else {
      medium = mediumOrganic;
    }
    return InstallSource(
      source: source ?? (fromAds ? sourceGoogleAds : sourceUnknown),
      medium: medium,
      campaign: values['utm_campaign'],
      content: values['utm_content'],
      term: values['utm_term'],
      fromGoogleAds: fromAds,
    );
  }

  static Map<String, String> _pairs(String? referrer) {
    final Map<String, String> values = <String, String>{};
    if (referrer == null || referrer.trim().isEmpty) return values;
    // Some browsers hand the value over still encoded
    // ("utm_source%3Dwhatsapp%26...").
    final String text = referrer.contains('=') ? referrer : _decode(referrer);
    for (final String part in text.split('&')) {
      final int equals = part.indexOf('=');
      if (equals <= 0) continue;
      final String key = part.substring(0, equals).trim().toLowerCase();
      final String value = _decode(part.substring(equals + 1)).trim();
      if (key.isEmpty || _unset.contains(value.toLowerCase())) continue;
      values[key] = value.length > _maxValueLength
          ? value.substring(0, _maxValueLength)
          : value;
    }
    return values;
  }

  static String _decode(String text) {
    try {
      return Uri.decodeQueryComponent(text);
    } catch (_) {
      // A referrer is whatever the link's author typed.
      return text;
    }
  }
}
