import 'dart:async';

import 'package:flutter/widgets.dart';

/// The domain of the HTTPS App Links this app claims. It must match the
/// `android:host` in AndroidManifest.xml, and the domain must serve
/// `/.well-known/assetlinks.json` for Android to open links without asking.
const String kDeepLinkHost = 'notes-f36b3.web.app';

/// `https://<kDeepLinkHost>/onboarding` starts the details form and paywall.
const String kOnboardingPath = '/onboarding';

/// `notes://onboarding`, the local test link. It needs no domain and no
/// per-device approval. Only debug builds register the scheme
/// (android/app/src/debug/AndroidManifest.xml), so a release build can never
/// be sent it.
const String kLocalLinkScheme = 'notes';
const String kLocalOnboardingHost = 'onboarding';

/// True for a link that should start the onboarding flow.
///
/// The host is allowed to be empty because iOS, and Android when the engine is
/// handed only a path, can deliver the link without its origin.
bool isOnboardingLink(Uri uri) {
  if (uri.scheme == kLocalLinkScheme) return uri.host == kLocalOnboardingHost;
  if (uri.host.isNotEmpty && uri.host != kDeepLinkHost) return false;
  return uri.path == kOnboardingPath ||
      uri.path.startsWith('$kOnboardingPath/');
}

/// Receives deep links from the platform without a plugin.
///
/// Flutter already delivers them: a cold-start link is the platform's
/// `defaultRouteName`, and a link opened while the app runs arrives through
/// [didPushRouteInformation].
class DeepLinkService with WidgetsBindingObserver {
  DeepLinkService(this._binding);

  final WidgetsBinding _binding;
  final StreamController<Uri> _links = StreamController<Uri>.broadcast();

  /// Links opened while the app is running.
  Stream<Uri> get links => _links.stream;

  /// The link that launched the app, or null for an ordinary launch.
  Uri? get initialLink {
    final String route = _binding.platformDispatcher.defaultRouteName;
    if (route == Navigator.defaultRouteName) return null;
    return Uri.tryParse(route);
  }

  /// Must be called before `runApp`. Observers are asked in registration
  /// order and the first to return true wins; WidgetsApp registers one too,
  /// and its handler calls `Navigator.pushNamed`, which throws in an app with
  /// no named routes.
  void start() => _binding.addObserver(this);

  void dispose() {
    _binding.removeObserver(this);
    unawaited(_links.close());
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    _links.add(routeInformation.uri);
    // Always handled, even for a link nothing listens for, so that it never
    // falls through to WidgetsApp's pushNamed.
    return true;
  }
}
