import 'package:flutter_test/flutter_test.dart';
import 'package:evos/models/attribution.dart';
import 'package:evos/models/onboarding.dart';
import 'package:evos/services/analytics.dart';
import 'package:evos/services/attribution_service.dart';
import 'package:evos/services/evos_backend.dart';
import 'package:evos/services/install_referrer_service.dart';
import 'package:evos/services/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

/// What Play hands over for a Meta ad click: the ad itself is encrypted in
/// utm_content, and utm_campaign is Meta's own placeholder.
const String metaReferrer = 'utm_source=apps.facebook.com&utm_campaign=fb4a'
    '&utm_content=%7B%22app%22%3A2015134735846694%2C%22t%22%3A1%2C%22source'
    '%22%3A%7B%22data%22%3A%22ab12%22%2C%22nonce%22%3A%22cd34%22%7D%7D';

const MetaAd sampleAd = MetaAd(
  campaign: 'Evos_AppInstalls_Hindi',
  campaignId: '120211112222333344',
  adset: 'Broad_18-45',
  adsetId: '120298765432109876',
  ad: 'Evos_Reel_Hindi_30s',
  adId: '120212345678901234',
  publisherPlatform: 'instagram',
  platformPosition: 'instagram_reels',
  isInstagram: true,
);

void main() {
  group('Attribution.fromReferrer', () {
    test('no referrer is unknown', () {
      for (final String? referrer in <String?>[null, '', '  ']) {
        expect(Attribution.fromReferrer(referrer).installSource, 'unknown');
      }
    });

    test("Play's store-search referrer is organic", () {
      final Attribution a = Attribution.fromReferrer(
        'utm_source=google-play&utm_medium=organic',
      );
      expect(a.installSource, 'organic');
      expect(a.toProperties(), <String, Object>{'install_source': 'organic'});
    });

    test('a Meta ad click is meta and paid, and the encrypted blob is never '
        'taken for the ad name', () {
      final Attribution a = Attribution.fromReferrer(metaReferrer);
      expect(a.installSource, 'meta');
      expect(a.utmSource, 'meta');
      expect(a.utmMedium, 'paid');
      expect(a.utmCampaign, isNull);
      expect(a.utmContent, isNull);
    });

    test('a link naming a Meta source is meta, with its own utm fields', () {
      final Attribution a = Attribution.fromReferrer(
        'utm_source=Facebook&utm_campaign=diwali&utm_term=set1&utm_content=ad1',
      );
      expect(a.installSource, 'meta');
      expect(a.utmSource, 'meta');
      expect(a.utmCampaign, 'diwali');
      expect(a.utmTerm, 'set1');
      expect(a.utmContent, 'ad1');
    });

    test('Google Ads click ids make google_ads; gad_campaignid is the '
        'campaign id', () {
      for (final String id in <String>['gclid', 'gbraid', 'wbraid']) {
        expect(
          Attribution.fromReferrer('$id=abc').installSource,
          'google_ads',
        );
      }
      final Attribution a = Attribution.fromReferrer(
        'gclid=Cj0abc&gad_source=1&gad_campaignid=21876543210',
      );
      expect(a.utmSource, 'google');
      expect(a.utmMedium, 'paid');
      expect(a.campaignId, '21876543210');
      expect(a.gclid, 'Cj0abc');
    });

    test('any other source is other, keeping what the link set', () {
      final Attribution a = Attribution.fromReferrer(
        'utm_source=whatsapp&utm_medium=influencer&utm_content=khushi_video1'
        '&flow=onboarding',
      );
      expect(a.installSource, 'other');
      expect(a.toProperties(), <String, Object>{
        'install_source': 'other',
        'utm_source': 'whatsapp',
        'utm_medium': 'influencer',
        'utm_content': 'khushi_video1',
      });
    });

    test('isMetaEncryptedReferrer spots only Meta ad clicks', () {
      expect(isMetaEncryptedReferrer(metaReferrer), isTrue);
      expect(
        isMetaEncryptedReferrer('utm_source=apps.instagram.com&utm_content=x'),
        isTrue,
      );
      expect(isMetaEncryptedReferrer('utm_source=facebook'), isFalse);
      expect(isMetaEncryptedReferrer(null), isFalse);
    });
  });

  group('Attribution', () {
    test('fromMetaAd maps campaign, ad set and ad to utm_*', () {
      final Attribution a = Attribution.fromMetaAd(sampleAd);
      expect(a.toProperties(), <String, Object>{
        'install_source': 'meta',
        'utm_source': 'meta',
        'utm_medium': 'paid',
        'utm_campaign': 'Evos_AppInstalls_Hindi',
        'utm_term': 'Broad_18-45',
        'utm_content': 'Evos_Reel_Hindi_30s',
        'campaign_id': '120211112222333344',
        'adset_id': '120298765432109876',
        'ad_id': '120212345678901234',
      });
    });

    test('MetaAd.fromJson keeps ids as text', () {
      final MetaAd? ad = MetaAd.fromJson(<String, Object?>{
        'campaign': 'C',
        'campaign_id': '120211112222333344',
        'adset': null,
        'ad_id': '120212345678901234',
        'is_instagram': false,
      });
      expect(ad!.campaign, 'C');
      expect(ad.campaignId, '120211112222333344');
      expect(ad.adset, isNull);
      expect(ad.adId, '120212345678901234');
      expect(ad.isInstagram, isFalse);
      expect(MetaAd.fromJson(null), isNull);
    });

    test('first-touch properties are prefixed and leave out install_source', () {
      expect(
        Attribution.fromMetaAd(sampleAd).toFirstTouchProperties(),
        containsPair('first_utm_content', 'Evos_Reel_Hindi_30s'),
      );
      expect(
        Attribution.fromMetaAd(sampleAd).toFirstTouchProperties(),
        isNot(contains('first_install_source')),
      );
    });

    test('encode and decode round-trip; junk decodes to null', () {
      final Attribution a = Attribution.fromReferrer('gclid=x&gad_campaignid=1');
      expect(Attribution.decode(a.encode())!.encode(), a.encode());
      expect(Attribution.decode(null), isNull);
      expect(Attribution.decode('not json'), isNull);
      expect(Attribution.decode('{"install_source":"bogus"}'), isNull);
    });

    test('fromLink reads utm_* from a link, and ignores a link without any',
        () {
      final Attribution? a = Attribution.fromLink(
        Uri.parse('https://example.com/onboarding?utm_source=youtube'
            '&utm_content=khushi_video1'),
      );
      expect(a!.installSource, 'other');
      expect(a.utmContent, 'khushi_video1');
      expect(Attribution.fromLink(Uri.parse('https://example.com/x')), isNull);
    });

    test('toRpcParams names every RPC argument', () {
      expect(Attribution.fromMetaAd(sampleAd).toRpcParams(), <String, Object?>{
        'p_install_source': 'meta',
        'p_utm_source': 'meta',
        'p_utm_medium': 'paid',
        'p_utm_campaign': 'Evos_AppInstalls_Hindi',
        'p_utm_term': 'Broad_18-45',
        'p_utm_content': 'Evos_Reel_Hindi_30s',
        'p_campaign_id': '120211112222333344',
        'p_adset_id': '120298765432109876',
        'p_ad_id': '120212345678901234',
        'p_gclid': null,
      });
    });
  });

  group('recordInstallAttribution', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('remembers the install, registers it, and sends Install Attributed '
        'once', () async {
      final OnboardingStore store = await OnboardingStore.open();
      final Recorder recorder = Recorder();
      await recordInstallAttribution(
        store: store,
        analytics: Analytics(recorder),
        answer: const InstallReferrer(referrer: metaReferrer, clickSeconds: 5),
        attempt: 1,
      );
      expect(store.latestAttribution!.installSource, 'meta');
      expect(store.firstAttribution!.installSource, 'meta');
      expect(store.installAttributedHere, isTrue);
      expect(recorder.events, <String>['Install Attributed']);
      expect(recorder.otherMethods, <String>['setAttribution']);
      final Map<String, Object?> properties =
          recorder.properties('Install Attributed');
      expect(properties['install_source'], 'meta');
      expect(properties['referrer_click_recorded'], true);
      expect((properties['install_referrer_raw']! as String).length, 100);
    });
  });

  group('AttributionService', () {
    late OnboardingStore store;
    late Recorder recorder;
    late FakeBackend backend;
    String? playReferrer;
    int referrerReads = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = await OnboardingStore.open();
      recorder = Recorder();
      backend = FakeBackend(store);
      playReferrer = null;
      referrerReads = 0;
    });

    AttributionService service() => AttributionService(
          store: store,
          backend: backend,
          analytics: Analytics(recorder),
          readReferrer: () async {
            referrerReads += 1;
            return playReferrer == null
                ? null
                : InstallReferrer(referrer: playReferrer!);
          },
        );

    Future<void> freshInstall(String referrer) => recordInstallAttribution(
          store: store,
          analytics: Analytics(Recorder()),
          answer: InstallReferrer(referrer: referrer),
          attempt: 1,
        ).then((_) => store.markInstallReferrerChecked());

    test('a new Meta install is decoded: the ad becomes the latest and the '
        'first touch, and Meta Ad Attributed is sent', () async {
      await freshInstall(metaReferrer);
      backend.metaResult = const MetaDecodeResult.decoded(sampleAd);

      await service().start(referrerThisLaunch: metaReferrer);

      expect(backend.decodedReferrers, <String>[metaReferrer]);
      expect(store.latestAttribution!.utmContent, 'Evos_Reel_Hindi_30s');
      expect(store.firstAttribution!.utmContent, 'Evos_Reel_Hindi_30s');
      expect(store.metaReferrerSettled, isTrue);
      expect(recorder.events, <String>['Meta Ad Attributed']);
      final Map<String, Object?> properties =
          recorder.properties('Meta Ad Attributed');
      expect(properties['ad_id'], '120212345678901234');
      expect(properties['utm_term'], 'Broad_18-45');
      expect(properties['publisher_platform'], 'instagram');
      expect(properties['is_new_install'], true);
      final Map<String, Object?> registered = recorder.calls
          .firstWhere(((String, Map<String, Object?>) c) =>
              c.$1 == 'setAttribution')
          .$2;
      expect(
        registered['latest'],
        containsPair('utm_content', 'Evos_Reel_Hindi_30s'),
      );
      expect(
        registered['first'],
        containsPair('first_utm_content', 'Evos_Reel_Hindi_30s'),
      );
    });

    test('the full referrer is sent, never a cut copy', () async {
      final String long = '$metaReferrer${'0' * 400}';
      await freshInstall(long);
      await service().start(referrerThisLaunch: long);
      expect(backend.decodedReferrers.single, long);
    });

    test('a referrer that is not a Meta ad click never reaches the backend',
        () async {
      await freshInstall('utm_source=google-play&utm_medium=organic');
      await service().start(
        referrerThisLaunch: 'utm_source=google-play&utm_medium=organic',
      );
      expect(backend.decodedReferrers, isEmpty);
      expect(store.metaReferrerSettled, isTrue);
    });

    test('nothing is decoded until the install referrer is final', () async {
      await service().start(referrerThisLaunch: '');
      expect(backend.decodedReferrers, isEmpty);
      expect(store.metaReferrerSettled, isFalse);
      expect(referrerReads, 0);
    });

    test('a refusal (4xx) settles at once and keeps the undecoded meta source',
        () async {
      await freshInstall(metaReferrer);
      backend.metaResult = const MetaDecodeResult(MetaDecodeStatus.rejected);
      await service().start(referrerThisLaunch: metaReferrer);
      expect(store.metaReferrerSettled, isTrue);
      expect(store.latestAttribution!.installSource, 'meta');
      expect(recorder.events, isEmpty);
    });

    test('a network error or 5xx is retried on later launches, up to '
        '$kReferrerMaxAttempts', () async {
      await freshInstall(metaReferrer);
      playReferrer = metaReferrer;
      backend.metaResult = const MetaDecodeResult(MetaDecodeStatus.retryLater);
      for (int launch = 1; launch <= kReferrerMaxAttempts; launch++) {
        expect(store.metaReferrerSettled, isFalse);
        // Later launches no longer hold the referrer, so read it from Play.
        await service().start();
      }
      expect(backend.decodedReferrers.length, kReferrerMaxAttempts);
      expect(store.metaReferrerSettled, isTrue);
      await service().start();
      expect(backend.decodedReferrers.length, kReferrerMaxAttempts);
    });

    test('after an update from an older version the referrer is read once: '
        'the install is attributed without a second Install Attributed, and '
        'a Meta ad is decoded as not new', () async {
      // The older version marked the referrer read but saved no attribution.
      await store.markInstallReferrerChecked();
      playReferrer = metaReferrer;
      backend.metaResult = const MetaDecodeResult.decoded(sampleAd);

      await service().start();

      expect(referrerReads, 1);
      expect(recorder.events, <String>['Meta Ad Attributed']);
      expect(
        recorder.properties('Meta Ad Attributed')['is_new_install'],
        false,
      );
      expect(store.latestAttribution!.adId, '120212345678901234');
    });

    test('after an update, a non-Meta install is attributed from its referrer',
        () async {
      await store.markInstallReferrerChecked();
      playReferrer = 'gclid=abc';
      await service().start();
      expect(store.latestAttribution!.installSource, 'google_ads');
      expect(store.metaReferrerSettled, isTrue);
      expect(recorder.events, isEmpty);
    });

    test('the latest ad is saved to the server once, for a signed-in user',
        () async {
      await freshInstall('utm_source=whatsapp');
      await store.saveSession('session');

      await service().start();
      await service().start();

      expect(backend.savedAttributions.length, 1);
      expect(backend.savedAttributions.single.utmSource, 'whatsapp');
    });

    test('a failed save is tried again on the next launch', () async {
      await freshInstall('utm_source=whatsapp');
      await store.saveSession('session');
      backend.attributionError = BackendError.network;
      await service().start();
      backend.attributionError = null;
      await service().start();
      expect(backend.savedAttributions.length, 1);
    });

    test('a new sign-in saves the ad again, even if this phone already saved '
        'it for someone else', () async {
      await freshInstall('utm_source=whatsapp');
      await store.saveSession('session');
      await service().start();
      // Another person signs in on the same phone.
      await service().syncToServer(newSignIn: true);
      expect(backend.savedAttributions.length, 2);
    });

    test('a Meta ad decoded late does not replace a newer link as the latest',
        () async {
      await freshInstall(metaReferrer);
      playReferrer = metaReferrer;
      backend.metaResult = const MetaDecodeResult(MetaDecodeStatus.retryLater);
      await service().start();
      await service().recordLink(
        Uri.parse('https://example.com/?utm_source=youtube&utm_content=v1'),
      );
      backend.metaResult = const MetaDecodeResult.decoded(sampleAd);
      await service().start();
      expect(store.latestAttribution!.utmContent, 'v1');
      expect(store.firstAttribution!.utmContent, 'Evos_Reel_Hindi_30s');
      expect(recorder.events, contains('Meta Ad Attributed'));
    });

    test('nothing is saved for a signed-out user or the review account',
        () async {
      await freshInstall('utm_source=whatsapp');
      await service().start();
      await store.save(
        const OnboardingState(
          stage: OnboardingStage.notes,
          reviewAccount: true,
        ),
      );
      await store.saveSession('session');
      await service().syncToServer();
      expect(backend.savedAttributions, isEmpty);
    });

    test('a link with utm_* becomes the latest ad but not the first touch',
        () async {
      await freshInstall('utm_source=google-play&utm_medium=organic');
      await service().recordLink(
        Uri.parse('https://example.com/?utm_source=youtube&utm_content=v1'),
      );
      expect(store.latestAttribution!.utmContent, 'v1');
      expect(store.firstAttribution!.installSource, 'organic');
      await service().recordLink(Uri.parse('https://example.com/onboarding'));
      expect(store.latestAttribution!.utmContent, 'v1');
    });
  });
}
