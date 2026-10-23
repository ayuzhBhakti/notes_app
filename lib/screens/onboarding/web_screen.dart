import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../models/remote_config.dart';
import '../../providers.dart';
import '../../widgets/brand.dart';

/// Where a subscriber, and the store-review account, lands: the web page in
/// the backend's `webview_url` row.
///
/// The URL is read from the settings, so it can change without an app update.
/// With no URL set there is a "come back soon" screen instead.
class WebScreen extends ConsumerStatefulWidget {
  const WebScreen({super.key});

  @override
  ConsumerState<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends ConsumerState<WebScreen> {
  final GlobalKey<_WebPageState> _page = GlobalKey<_WebPageState>();
  late final AppLifecycleListener _lifecycle;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final String? url = ref.read(remoteConfigProvider).webUrl;
    ref.read(analyticsProvider).webPageViewed(
          hasUrl: url != null,
          source: ref.read(onboardingStoreProvider).installSource,
          webHost: url == null ? null : Uri.tryParse(url)?.host,
        );
    // A subscription can end while the app is in the background; the
    // refresh then moves the device back to the paywall.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(onboardingControllerProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await ref.read(onboardingControllerProvider.notifier).refresh();
    // The refresh can move the device to another screen, which removes this one.
    if (!mounted) return;
    setState(() => _checking = false);
    if (ref.read(remoteConfigProvider).webUrl == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nothing new yet. Check back later.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final RemoteConfig config = ref.watch(remoteConfigProvider);
    final String? url = config.webUrl;

    return Semantics(
      identifier: 'web_screen',
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: const BrandHeader(),
          actions: <Widget>[
            if (url != null)
              IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _page.currentState?.reload(),
              ),
            Semantics(
              identifier: 'web_menu_button',
              child: PopupMenuButton<void>(
                tooltip: 'More',
                itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
                  PopupMenuItem<void>(
                    onTap: () => ref
                        .read(onboardingControllerProvider.notifier)
                        .signOut(),
                    child: Semantics(
                      identifier: 'web_logout_button',
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: url == null
            ? _NoPage(checking: _checking, onCheckAgain: _checkAgain)
            // Keyed by the URL, so a new one from the backend starts afresh.
            : _WebPage(key: _page, url: url),
      ),
    );
  }
}

/// The web page itself, with the WebView set up to behave like a browser.
class _WebPage extends ConsumerStatefulWidget {
  const _WebPage({super.key, required this.url});

  final String url;

  @override
  ConsumerState<_WebPage> createState() => _WebPageState();
}

class _WebPageState extends ConsumerState<_WebPage> {
  /// Null where no WebView implementation is registered: widget tests, and
  /// platforms this app does not build for.
  WebViewController? _controller;
  int _progress = 0;
  bool _failed = false;
  int? _textZoom;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance == null) return;
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (String _) {
            if (mounted) setState(() => _failed = false);
          },
          onWebResourceError: (WebResourceError error) {
            // A missing image or script must not cover a page that loaded.
            if (error.isForMainFrame == false || !mounted) return;
            ref
                .read(analyticsProvider)
                .webPageFailed(error.errorType?.name ?? 'unknown');
            setState(() => _failed = true);
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      );
    final Object platform = controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      // Lets a page start its own video or audio, as a browser tab would.
      platform.setMediaPlaybackRequiresUserGesture(false);
      // Sign-in and payment pages often run in a frame from another site.
      AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      ).setAcceptThirdPartyCookies(platform, true);
    }
    controller.loadRequest(Uri.parse(widget.url));
    _controller = controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Follows the phone's font size setting, which an Android WebView
    // otherwise ignores.
    final int zoom = MediaQuery.textScalerOf(context).scale(100).round();
    final Object? platform = _controller?.platform;
    if (zoom != _textZoom && platform is AndroidWebViewController) {
      _textZoom = zoom;
      platform.setTextZoom(zoom);
    }
  }

  /// The web loads here; anything else (tel:, mailto:, upi:, whatsapp:) goes
  /// to the app on the phone that handles it.
  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final Uri? uri = Uri.tryParse(request.url);
    if (uri == null || uri.isScheme('http') || uri.isScheme('https') ||
        uri.isScheme('about') || uri.isScheme('data') || uri.isScheme('blob')) {
      return NavigationDecision.navigate;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No app for it. The page stays where it was.
    }
    return NavigationDecision.prevent;
  }

  void reload() {
    final WebViewController? controller = _controller;
    if (controller == null) return;
    setState(() => _failed = false);
    // After a failed first load there is no page to reload.
    controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _back() async {
    final WebViewController? controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebViewController? controller = _controller;
    if (controller == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This page cannot be shown on this device.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Back goes back in the page's history first, as in a browser.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop) _back();
      },
      child: Stack(
        children: <Widget>[
          WebViewWidget(controller: controller),
          if (_failed) _LoadFailed(onRetry: reload),
          if (_progress < 100 && !_failed)
            LinearProgressIndicator(value: _progress / 100),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                "This page couldn't be loaded.",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the backend has no `webview_url`.
class _NoPage extends StatelessWidget {
  const _NoPage({required this.checking, required this.onCheckAgain});

  final bool checking;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(34),
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            size: 64,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        "You're all set",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your access is active. The page is not available yet; '
                        'check again in a little while.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              identifier: 'web_check_again_button',
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.tonal(
                  onPressed: checking ? null : onCheckAgain,
                  child: checking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Check again'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
