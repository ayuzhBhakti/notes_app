import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/remote_config.dart';
import '../providers.dart';

/// Gives the deep-link interface the name and colour the backend sent.
///
/// Wraps only that interface: the notes app above it in `main.dart` keeps its
/// own theme and title. The launcher icon and the name under it are fixed
/// when the app is built and are not affected.
class BrandShell extends ConsumerWidget {
  const BrandShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RemoteConfig config = ref.watch(remoteConfigProvider);
    final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: config.seedColor,
        // The default variant mutes the seed until a brand colour is hard to
        // recognise. This one keeps buttons close to the colour that was sent.
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        // Light or dark still follows the phone, as the notes app does.
        brightness: Theme.of(context).brightness,
      ),
    );

    // What the recent-apps screen calls the app while this interface is up.
    return Title(
      title: config.appName,
      color: theme.colorScheme.primary.withValues(alpha: 1),
      // Animated, so a colour arriving from the server a moment after the
      // first frame fades in instead of snapping.
      child: AnimatedTheme(data: theme, child: child),
    );
  }
}

/// The backend's logo, or the first letter of the app name on a tile while
/// there is none or it cannot be loaded.
class BrandLogo extends ConsumerWidget {
  const BrandLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RemoteConfig config = ref.watch(remoteConfigProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? url = config.logoUrl;

    final Widget letter = ColoredBox(
      color: colors.primary,
      child: Center(
        child: Text(
          config.appName.characters.first.toUpperCase(),
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );

    return Semantics(
      label: '${config.appName} logo',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: SizedBox.square(
          dimension: size,
          child: url == null
              ? letter
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // Sized to the tile, so a large upload costs no more memory.
                  cacheWidth:
                      (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                      letter,
                  loadingBuilder: (
                    BuildContext _,
                    Widget image,
                    ImageChunkEvent? progress,
                  ) =>
                      progress == null ? image : letter,
                ),
        ),
      ),
    );
  }
}

/// The logo with the app name beside it, for the top of a screen.
class BrandHeader extends ConsumerWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String appName = ref.watch(
      remoteConfigProvider.select((RemoteConfig c) => c.appName),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const BrandLogo(size: 32),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
