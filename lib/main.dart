import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'firebase_options.dart';
import 'models/install_source.dart';
import 'providers.dart';
import 'screens/app_gate.dart';
import 'services/analytics.dart';
import 'services/deep_link_service.dart';
import 'services/install_referrer_service.dart';
import 'services/onboarding_store.dart';
import 'theme.dart';
import 'utils/errors.dart';

Future<void> main() async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

  // The app is portrait-only. The Android manifest also locks the activity
  // (covering the native splash); this covers the Flutter side and iOS.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // Before runApp, so this observer is asked about an incoming link ahead of
  // the one WidgetsApp registers. See DeepLinkService.start.
  final DeepLinkService deepLinks = DeepLinkService(binding)..start();

  // The same stateless object analyticsProvider hands out; made here because
  // these two events come before there is a ProviderScope to read it from.
  const Analytics analytics = Analytics(MethodChannelAnalyticsClient());
  analytics.appOpened();

  final OnboardingStore onboardingStore;
  String? installReferrer;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    onboardingStore = await OnboardingStore.open();

    // Until Play has given an answer that settles it (see isReferrerFinal).
    // For attribution only: everyone signs in by phone whatever it says. A
    // failed read is left unmarked and tried again on the next launch.
    if (!onboardingStore.installReferrerChecked) {
      final InstallReferrer? answer =
          await const InstallReferrerService().fetch();
      if (answer != null) {
        final int attempt = onboardingStore.installReferrerAttempts + 1;
        if (isReferrerFinal(answer.referrer, attempt)) {
          await onboardingStore.markInstallReferrerChecked();
        } else {
          await onboardingStore.saveInstallReferrerAttempts(attempt);
        }
        final InstallSource source = InstallSource.parse(answer.referrer);
        analytics.installAttributed(
          source,
          referrer: answer.referrer,
          clickRecorded: answer.clickSeconds > 0,
          attempt: attempt,
        );
        // Remembered for the web-page step, which runs many launches later and
        // no longer has the referrer. Anything but the unattributed default is
        // worth keeping; an unmatched source just falls back to the global URL.
        if (source.source != InstallSource.sourceUnknown) {
          await onboardingStore.saveInstallSource(source.source.toLowerCase());
        }
        installReferrer = answer.referrer;
      }
    }
  } catch (error) {
    // A failure here means the app can never work, so show why rather than
    // leaving the user on a black screen.
    runApp(_BootstrapErrorApp(failure: describeError(error)));
    return;
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        deepLinkServiceProvider.overrideWithValue(deepLinks),
        onboardingStoreProvider.overrideWithValue(onboardingStore),
        installReferrerProvider.overrideWithValue(installReferrer),
      ],
      child: const NotesApp(),
    ),
  );
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evos',
      debugShowCheckedModeBanner: false,
      theme: buildNotesTheme(Brightness.light),
      darkTheme: buildNotesTheme(Brightness.dark),
      // No `home`: a cold-start deep link reaches Flutter as the platform's
      // initial route name, which takes precedence over `initialRoute`. With
      // `home`, the Navigator would try to push that URL as a named route and
      // report an error. The link is read by DeepLinkService instead, so
      // whatever the initial route name is, the app starts on the one root
      // route. `home` and `onGenerateInitialRoutes` cannot be combined, hence
      // `onGenerateRoute`.
      onGenerateInitialRoutes: (String _) => <Route<void>>[_rootRoute()],
      onGenerateRoute: (RouteSettings _) => _rootRoute(),
    );
  }

  static Route<void> _rootRoute() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: Navigator.defaultRouteName),
        builder: (BuildContext _) => const AppGate(),
      );
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.failure});

  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Evos couldn't start",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(failure.message, textAlign: TextAlign.center),
              if (failure.hint != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  failure.hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
