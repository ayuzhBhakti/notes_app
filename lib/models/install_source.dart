/// Long enough for any real campaign name, short enough that a junk link
/// cannot bloat every event.
const int kReferrerValueMaxLength = 100;

const Set<String> _unset = <String>{'', '(not set)', 'not set'};

/// The key/value pairs of a Play install referrer or a link's query, keys
/// lowercased. Never fails: unset values (`(not set)`) are dropped, malformed
/// percent-encoding is kept as typed, and each value is cut to [maxLength].
/// Not for Meta's encrypted `utm_content`, which must reach the backend whole.
Map<String, String> referrerPairs(
  String? referrer, {
  int maxLength = kReferrerValueMaxLength,
}) {
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
    values[key] =
        value.length > maxLength ? value.substring(0, maxLength) : value;
  }
  return values;
}

String _decode(String text) {
  try {
    return Uri.decodeQueryComponent(text);
  } catch (_) {
    // A referrer is whatever the link's author typed.
    return text;
  }
}

/// The install's raw source, as carried by a tracked Play Store link
/// (`...&referrer=utm_source%3Dwhatsapp%26utm_campaign%3Ddiwali`) and handed to
/// the app by Google Play on first launch. Fields the link did not set are
/// null.
///
/// Its lowercased [source] is saved as `install_source_v1` and picks the
/// per-source settings and price (`webview_sources`). Analytics reads the
/// install through `Attribution` instead. Whether the install starts
/// onboarding is decided separately by `isOnboardingReferrer`.
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

  /// Never fails: an empty, missing or unreadable referrer is an organic
  /// install from an unknown source. Play itself reports a store search as
  /// `utm_source=google-play&utm_medium=organic`.
  static InstallSource parse(String? referrer) {
    final Map<String, String> values = referrerPairs(referrer);
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
}
