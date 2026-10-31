import 'dart:convert';

import 'install_source.dart' show referrerPairs;

/// `utm_source` of a Meta ad click in the Play install referrer. Its
/// `utm_content` is the ad, encrypted; only the meta-install-referrer edge
/// function can read it.
const Set<String> kMetaReferrerSources = <String>{
  'apps.facebook.com',
  'apps.instagram.com',
};

/// `utm_source` values a link author may type for Meta.
const Set<String> _metaSourceNames = <String>{
  'meta',
  'facebook',
  'fb',
  'instagram',
  'ig',
};

/// A Google Ads click puts one of these in the referrer.
const List<String> _googleClickIds = <String>['gclid', 'gbraid', 'wbraid'];

/// Google's click id runs to about 100 characters, so values get more room
/// here than in `InstallSource`. Still under Mixpanel's 255.
const int _maxValueLength = 200;

/// True for a referrer whose ad Meta encrypted, the only kind worth sending to
/// the backend.
bool isMetaEncryptedReferrer(String? referrer) => kMetaReferrerSources
    .contains(referrerPairs(referrer)['utm_source']?.toLowerCase());

/// Which ad (or source) a user came from: the one model behind the Mixpanel
/// super properties, the person's profile and the `profiles` ad columns.
///
/// Fields a source did not set are null. For a Meta ad, [utmCampaign] is the
/// campaign, [utmTerm] the ad set and [utmContent] the ad.
class Attribution {
  const Attribution({
    required this.installSource,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    this.campaignId,
    this.adsetId,
    this.adId,
    this.gclid,
  });

  static const String sourceMeta = 'meta';
  static const String sourceGoogleAds = 'google_ads';
  static const String sourceOrganic = 'organic';
  static const String sourceOther = 'other';
  static const String sourceUnknown = 'unknown';
  static const Set<String> installSources = <String>{
    sourceMeta,
    sourceGoogleAds,
    sourceOrganic,
    sourceOther,
    sourceUnknown,
  };

  /// meta, google_ads, organic, other or unknown.
  final String installSource;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmTerm;
  final String? utmContent;
  final String? campaignId;
  final String? adsetId;
  final String? adId;

  /// Kept for a later Google Ads API lookup. Never sent to Mixpanel.
  final String? gclid;

  /// Organic and unknown installs name no ad, and never replace one.
  bool get namesAnAd =>
      installSource != sourceOrganic && installSource != sourceUnknown;

  /// Whether a campaign, ad set or ad is known, not just the source.
  bool get hasDetails =>
      utmCampaign != null ||
      utmTerm != null ||
      utmContent != null ||
      adId != null;

  /// From the Play install referrer. Never fails: an empty or unreadable one
  /// is unknown. A Meta ad click is `meta` with no names until the backend
  /// has decoded it (see [Attribution.fromMetaAd]).
  factory Attribution.fromReferrer(String? referrer) =>
      _classify(referrerPairs(referrer, maxLength: _maxValueLength)) ??
      const Attribution(installSource: sourceUnknown);

  /// From an incoming link's query. Null when the link carries no campaign.
  static Attribution? fromLink(Uri uri) {
    final Map<String, String> values =
        referrerPairs(uri.query, maxLength: _maxValueLength);
    final Attribution? attribution = _classify(values);
    return attribution != null && attribution.namesAnAd ? attribution : null;
  }

  factory Attribution.fromMetaAd(MetaAd ad) => Attribution(
        installSource: sourceMeta,
        utmSource: sourceMeta,
        utmMedium: 'paid',
        utmCampaign: ad.campaign,
        utmTerm: ad.adset,
        utmContent: ad.ad,
        campaignId: ad.campaignId,
        adsetId: ad.adsetId,
        adId: ad.adId,
      );

  static Attribution? _classify(Map<String, String> v) {
    final String? source = v['utm_source']?.toLowerCase();
    if (kMetaReferrerSources.contains(source)) {
      // utm_content is the encrypted ad and utm_campaign Meta's placeholder.
      return const Attribution(
        installSource: sourceMeta,
        utmSource: sourceMeta,
        utmMedium: 'paid',
      );
    }
    if (_metaSourceNames.contains(source)) {
      return _withLinkFields(v, sourceMeta, utmSource: sourceMeta);
    }
    if (_googleClickIds.any(v.containsKey)) {
      return Attribution(
        installSource: sourceGoogleAds,
        utmSource: v['utm_source'] ?? 'google',
        utmMedium: v['utm_medium'] ?? 'paid',
        utmCampaign: v['utm_campaign'],
        utmTerm: v['utm_term'],
        utmContent: v['utm_content'],
        // About one Google Ads install in seven carries the campaign number.
        campaignId: v['gad_campaignid'] ?? v['campaign_id'],
        gclid: v['gclid'],
      );
    }
    if (source == 'google-play') {
      return const Attribution(installSource: sourceOrganic);
    }
    if (source != null) {
      return _withLinkFields(v, sourceOther, utmSource: v['utm_source']);
    }
    return null;
  }

  static Attribution _withLinkFields(
    Map<String, String> v,
    String installSource, {
    required String? utmSource,
  }) =>
      Attribution(
        installSource: installSource,
        utmSource: utmSource,
        utmMedium: v['utm_medium'] ??
            (installSource == sourceMeta ? 'paid' : null),
        utmCampaign: v['utm_campaign'],
        utmTerm: v['utm_term'],
        utmContent: v['utm_content'],
        campaignId: v['campaign_id'],
        adsetId: v['adset_id'],
        adId: v['ad_id'],
      );

  /// As Mixpanel super properties: what every event carries. Absent fields
  /// are left out, not sent empty.
  Map<String, Object> toProperties() => <String, Object>{
        'install_source': installSource,
        'utm_source': ?utmSource,
        'utm_medium': ?utmMedium,
        'utm_campaign': ?utmCampaign,
        'utm_term': ?utmTerm,
        'utm_content': ?utmContent,
        'campaign_id': ?campaignId,
        'adset_id': ?adsetId,
        'ad_id': ?adId,
      };

  /// As the person's `first_*` profile properties, set once.
  Map<String, Object> toFirstTouchProperties() => <String, Object>{
        for (final MapEntry<String, Object> entry in toProperties().entries)
          if (entry.key != 'install_source') 'first_${entry.key}': entry.value,
      };

  /// The arguments of the `save_user_attribution` RPC.
  Map<String, Object?> toRpcParams() => <String, Object?>{
        'p_install_source': installSource,
        'p_utm_source': utmSource,
        'p_utm_medium': utmMedium,
        'p_utm_campaign': utmCampaign,
        'p_utm_term': utmTerm,
        'p_utm_content': utmContent,
        'p_campaign_id': campaignId,
        'p_adset_id': adsetId,
        'p_ad_id': adId,
        'p_gclid': gclid,
      };

  String encode() => jsonEncode(<String, Object?>{
        'install_source': installSource,
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        'utm_campaign': utmCampaign,
        'utm_term': utmTerm,
        'utm_content': utmContent,
        'campaign_id': campaignId,
        'adset_id': adsetId,
        'ad_id': adId,
        'gclid': gclid,
      });

  /// Null for anything that is not what [encode] wrote.
  static Attribution? decode(String? source) {
    if (source == null) return null;
    try {
      final Object? json = jsonDecode(source);
      if (json is! Map) return null;
      final Object? installSource = json['install_source'];
      if (installSource is! String || !installSources.contains(installSource)) {
        return null;
      }
      String? text(String key) {
        final Object? value = json[key];
        return value is String ? value : null;
      }

      return Attribution(
        installSource: installSource,
        utmSource: text('utm_source'),
        utmMedium: text('utm_medium'),
        utmCampaign: text('utm_campaign'),
        utmTerm: text('utm_term'),
        utmContent: text('utm_content'),
        campaignId: text('campaign_id'),
        adsetId: text('adset_id'),
        adId: text('ad_id'),
        gclid: text('gclid'),
      );
    } on FormatException {
      return null;
    }
  }
}

/// A Meta ad as decoded by the meta-install-referrer edge function. Ids are
/// text: they run to 18 digits.
class MetaAd {
  const MetaAd({
    this.campaign,
    this.campaignId,
    this.adset,
    this.adsetId,
    this.ad,
    this.adId,
    this.publisherPlatform,
    this.platformPosition,
    this.isInstagram,
  });

  final String? campaign;
  final String? campaignId;
  final String? adset;
  final String? adsetId;
  final String? ad;
  final String? adId;

  /// Such as `instagram` or `facebook`.
  final String? publisherPlatform;

  /// Such as `instagram_reels`.
  final String? platformPosition;
  final bool? isInstagram;

  /// Null when [json] is not an object.
  static MetaAd? fromJson(Object? json) {
    if (json is! Map) return null;
    String? text(String key) {
      final Object? value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return null;
    }

    final Object? isInstagram = json['is_instagram'];
    return MetaAd(
      campaign: text('campaign'),
      campaignId: text('campaign_id'),
      adset: text('adset'),
      adsetId: text('adset_id'),
      ad: text('ad'),
      adId: text('ad_id'),
      publisherPlatform: text('publisher_platform'),
      platformPosition: text('platform_position'),
      isInstagram: isInstagram is bool ? isInstagram : null,
    );
  }
}

/// What asking the backend to decode a referrer came to.
enum MetaDecodeStatus {
  /// A Meta ad, in [MetaDecodeResult.ad].
  decoded,

  /// Not a Meta ad click.
  notMeta,

  /// Refused for good (4xx: another app's ad, or it would not decrypt).
  rejected,

  /// No answer (offline, or a 5xx): ask again on a later launch.
  retryLater,
}

class MetaDecodeResult {
  const MetaDecodeResult(this.status) : ad = null;

  const MetaDecodeResult.decoded(MetaAd this.ad)
      : status = MetaDecodeStatus.decoded;

  final MetaDecodeStatus status;
  final MetaAd? ad;
}
