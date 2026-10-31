import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../models/attribution.dart';
import 'analytics.dart';
import 'evos_backend.dart';
import 'install_referrer_service.dart';
import 'onboarding_store.dart';

/// On the launch whose Play answer is final (see `isReferrerFinal`): keeps
/// the install's attribution, puts it on every later event, and sends
/// `Install Attributed`, once per install.
///
/// Runs in `main()` before there is a backend, so a Meta ad click is only
/// `meta` here; [AttributionService.start] decodes the ad afterwards.
Future<void> recordInstallAttribution({
  required OnboardingStore store,
  required Analytics analytics,
  required InstallReferrer answer,
  required int attempt,
}) async {
  final Attribution attribution = Attribution.fromReferrer(answer.referrer);
  await _remember(store, analytics, attribution);
  await store.markInstallAttributedHere();
  analytics.installAttributed(
    attribution,
    referrer: answer.referrer,
    clickRecorded: answer.clickSeconds > 0,
    attempt: attempt,
  );
}

/// Makes [attribution] the latest ad, and the first touch if there is none.
///
/// An organic or unknown source never replaces a known ad. [decodedInstall]
/// is set for a decoded Meta ad: it is the install's own ad, decoded late, so
/// it only fills in the nameless `meta` entries its referrer left. It never
/// replaces a link the user opened in the meantime.
Future<void> _remember(
  OnboardingStore store,
  Analytics analytics,
  Attribution attribution, {
  bool decodedInstall = false,
}) async {
  bool isNamelessMeta(Attribution? a) =>
      a != null && a.installSource == Attribution.sourceMeta && !a.hasDetails;

  final Attribution? latest = store.latestAttribution;
  final bool keepLatest = latest != null &&
      (decodedInstall
          ? !isNamelessMeta(latest)
          : latest.namesAnAd && !attribution.namesAnAd);
  final Attribution nextLatest = keepLatest ? latest : attribution;
  final Attribution? first = store.firstAttribution;
  final bool replaceFirst =
      first == null || (decodedInstall && isNamelessMeta(first));
  final Attribution nextFirst = replaceFirst ? attribution : first;

  await store.saveLatestAttribution(nextLatest);
  if (replaceFirst) await store.saveFirstAttribution(nextFirst);
  analytics.registerAttribution(latest: nextLatest, first: nextFirst);
}

/// Works out which ad this install came from and sends it everywhere: the
/// Mixpanel super properties and profile (through [Analytics]) and the user's
/// `profiles` row (through [EvosBackend.saveAttribution]).
///
/// A Meta ad click is decoded by the meta-install-referrer edge function,
/// which holds the key. That is retried on later launches while there is no
/// answer (offline, 5xx), up to [kReferrerMaxAttempts], and stops at a final
/// one. An install made by an older version, which never decoded, reads its
/// referrer once after the update (Play keeps it for 90 days).
class AttributionService {
  AttributionService({
    required this.store,
    required this.backend,
    required this.analytics,
    required this.readReferrer,
  });

  final OnboardingStore store;
  final EvosBackend backend;
  final Analytics analytics;

  /// Asks Play again, for a launch after the one that first read it.
  final Future<InstallReferrer?> Function() readReferrer;

  bool _started = false;

  /// Once per launch, after the first frame. [referrerThisLaunch] is Play's
  /// answer when `main()` read it on this launch, so it is not asked twice.
  Future<void> start({String? referrerThisLaunch}) async {
    if (_started) return;
    _started = true;
    try {
      await _resolveInstall(referrerThisLaunch);
    } catch (error) {
      // Attribution must never break the app; the next launch tries again.
      if (kDebugMode) debugPrint('[attribution] $error');
    }
    await syncToServer();
  }

  /// A link that carries a campaign becomes the latest ad (last touch).
  Future<void> recordLink(Uri uri) async {
    final Attribution? attribution = Attribution.fromLink(uri);
    if (attribution == null) return;
    await _remember(store, analytics, attribution);
    await syncToServer();
  }

  /// Saves the latest ad on the signed-in user's profile when it has changed
  /// since the last save. [newSignIn] saves it whatever was saved before: the
  /// last save may have been for another person on this phone. Skipped for
  /// the review account, which has no server account. Never throws: a
  /// failure is tried again later.
  Future<void> syncToServer({bool newSignIn = false}) async {
    final Attribution? latest = store.latestAttribution;
    if (latest == null ||
        !backend.isSignedIn ||
        store.load().reviewAccount) {
      return;
    }
    final String encoded = latest.encode();
    if (!newSignIn && store.syncedAttribution == encoded) return;
    try {
      await backend.saveAttribution(latest);
      await store.saveSyncedAttribution(encoded);
    } catch (error) {
      if (kDebugMode) debugPrint('[attribution] Not saved: $error');
    }
  }

  Future<void> _resolveInstall(String? referrerThisLaunch) async {
    // Until Play's answer is final, an empty one may still be filled in.
    if (store.metaReferrerSettled || !store.installReferrerChecked) return;

    final String? referrer =
        referrerThisLaunch ?? (await readReferrer())?.referrer;
    if (referrer == null) return _countFailedAttempt();

    if (store.latestAttribution == null) {
      // Installed by a version without this code: attribute it now, once.
      await _remember(store, analytics, Attribution.fromReferrer(referrer));
    }
    if (!isMetaEncryptedReferrer(referrer)) return store.settleMetaReferrer();

    final MetaDecodeResult result =
        await backend.decodeMetaReferrer(referrer);
    switch (result.status) {
      case MetaDecodeStatus.decoded:
        final MetaAd ad = result.ad!;
        await _remember(
          store,
          analytics,
          Attribution.fromMetaAd(ad),
          decodedInstall: true,
        );
        analytics.metaAdAttributed(
          ad,
          newInstall: store.installAttributedHere,
        );
        await store.settleMetaReferrer();
      case MetaDecodeStatus.notMeta:
      case MetaDecodeStatus.rejected:
        await store.settleMetaReferrer();
      case MetaDecodeStatus.retryLater:
        await _countFailedAttempt();
    }
  }

  Future<void> _countFailedAttempt() async {
    final int attempts = store.metaReferrerAttempts + 1;
    if (attempts >= kReferrerMaxAttempts) {
      await store.settleMetaReferrer();
    } else {
      await store.saveMetaReferrerAttempts(attempts);
    }
  }
}
