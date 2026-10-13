import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/remote_config.dart';
import '../../providers.dart';
import '../../services/payment_gateway.dart';
import '../../utils/errors.dart';
import '../../widgets/brand.dart';

/// Third screen of the deep-link flow: the trial offer, paid by UPI AutoPay.
///
/// Laid out like the CashAlert paywall: heading with a pill, rating, preview,
/// feature badges, the two prices, a line of social proof, and a bottom bar
/// with the UPI app on the left and "Try Now" on the right. The words, prices
/// and picture come from the backend; a part with nothing to show is left out.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// Null until the user picks; the first installed app is used until then.
  UpiApp? _picked;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).paywallViewed();
    // Coming back from the UPI app is the moment the server may know more
    // than the device: Android can restart the app while the UPI app is in
    // front, and the answer to the payment is then lost on the way back.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!ref.read(purchaseControllerProvider).isLoading) {
          ref.read(onboardingControllerProvider.notifier).refresh();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<UpiApp?> _pickUpiApp(List<UpiApp> apps, UpiApp? current) async {
    final UpiApp? chosen = await showModalBottomSheet<UpiApp>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => _UpiSheet(apps: apps, current: current),
    );
    if (chosen != null && mounted) {
      if (chosen.packageName != current?.packageName) {
        ref.read(analyticsProvider).upiAppSelected(chosen.name);
      }
      setState(() => _picked = chosen);
    }
    return chosen;
  }

  Future<void> _tryNow(List<UpiApp> apps, UpiApp? selected) async {
    // Nothing to pay with yet: the sheet says what to install.
    final UpiApp? app = selected ?? await _pickUpiApp(apps, null);
    if (app == null || !mounted) return;
    await ref.read(purchaseControllerProvider.notifier).subscribe(app);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final RemoteConfig config = ref.watch(remoteConfigProvider);
    final PaymentGateway gateway = ref.watch(paymentGatewayProvider);
    final AsyncValue<void> purchase = ref.watch(purchaseControllerProvider);
    final bool busy = purchase.isLoading;
    final List<UpiApp> apps =
        ref.watch(upiAppsProvider).value ?? const <UpiApp>[];
    // A pick made earlier can go stale if that app is uninstalled meanwhile.
    final UpiApp? selected = apps
            .where((UpiApp a) => a.packageName == _picked?.packageName)
            .firstOrNull ??
        apps.firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: <Widget>[
                  const Expanded(child: BrandHeader()),
                  Semantics(
                    identifier: 'paywall_logout_button',
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () => ref
                              .read(onboardingControllerProvider.notifier)
                              .signOut(),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: <Widget>[
                    _Heading(config: config),
                    if (config.ratingValue.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _Rating(
                        value: config.ratingValue,
                        caption: config.ratingCaption,
                      ),
                    ],
                    if (config.previewImageUrl != null) ...<Widget>[
                      const SizedBox(height: 22),
                      _Preview(url: config.previewImageUrl!),
                    ],
                    if (config.features.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 26),
                      _Features(features: config.features),
                    ],
                    const SizedBox(height: 28),
                    _Price(config: config),
                    const SizedBox(height: 12),
                    // Always shown, and never from the backend: this is the
                    // sentence that says money will be taken every month.
                    Text(
                      '${config.trialPriceLabel} today for the first 24 hours, '
                      'then ${config.recurringPriceLabel} every month by UPI '
                      'AutoPay. Cancel any time in your UPI app.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (config.socialProofs.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      _SocialProof(lines: config.socialProofs),
                    ],
                    if (gateway.isSimulated) ...<Widget>[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: colors.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Test mode: no payment is taken.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (purchase.hasError) ...<Widget>[
                      const SizedBox(height: 16),
                      _PurchaseError(error: purchase.error!),
                    ],
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        identifier: 'paywall_upi_selector',
                        button: true,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => _pickUpiApp(apps, selected),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  selected?.name ?? 'Select UPI App',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      identifier: 'paywall_try_now_button',
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: busy ? null : () => _tryNow(apps, selected),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(132, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Try Now'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1-Day [₹3] Trial": text, a filled pill, text.
class _Heading extends StatelessWidget {
  const _Heading({required this.config});

  final RemoteConfig config;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final String badge = config.paywallTitleBadge.isEmpty
        ? config.trialPriceLabel
        : config.paywallTitleBadge;

    return Semantics(
      header: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: <Widget>[
          if (config.paywallTitlePrefix.isNotEmpty)
            Text(config.paywallTitlePrefix, style: style),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                badge,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (config.paywallTitleSuffix.isNotEmpty)
            Text(config.paywallTitleSuffix, style: style),
        ],
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double stars = (double.tryParse(value) ?? 0).clamp(0, 5).toDouble();
    const Color gold = Color(0xFFF5A623);

    return Semantics(
      label: 'Rated $value out of 5. $caption',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < 5; i++)
                Icon(
                  stars >= i + 0.75
                      ? Icons.star_rounded
                      : stars >= i + 0.25
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                  size: 18,
                  color: gold,
                ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (caption.isNotEmpty)
            Text(
              caption,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            // The tinted box stays: a broken picture must not move the
            // price and the button around.
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.features});

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String feature in features)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feature,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The monthly price struck through beside the trial price, large.
class _Price extends StatelessWidget {
  const _Price({required this.config});

  final RemoteConfig config;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Semantics(
      label: '${config.trialPriceLabel} today, '
          'then ${config.recurringPriceLabel} a month',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            config.recurringPriceLabel,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationColor: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            config.trialPriceLabel,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line at a time from the backend's list, changing every few seconds.
class _SocialProof extends StatefulWidget {
  const _SocialProof({required this.lines});

  final List<String> lines;

  @override
  State<_SocialProof> createState() => _SocialProofState();
}

class _SocialProofState extends State<_SocialProof> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.lines.length > 1) {
      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (Timer _) => setState(() => _index += 1),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    // Modulo here, not in the timer: the list can shrink when the settings
    // are refreshed.
    final String line = widget.lines[_index % widget.lines.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[...previous, ?current],
                ),
                child: Text(
                  line,
                  key: ValueKey<String>(line),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseError extends StatelessWidget {
  const _PurchaseError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppFailure failure = describeError(error);
    return Semantics(
      liveRegion: true,
      child: Text(
        failure.hint == null
            ? failure.message
            : '${failure.message} ${failure.hint}',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _UpiSheet extends StatelessWidget {
  const _UpiSheet({required this.apps, required this.current});

  final List<UpiApp> apps;
  final UpiApp? current;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Pay with UPI AutoPay',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'No UPI app was found on this phone. Install PhonePe, '
                  'Google Pay, Paytm or BHIM, then come back.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final UpiApp app in apps)
              Semantics(
                identifier: 'upi_app_${app.packageName}',
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(app.name.characters.first),
                  ),
                  title: Text(app.name),
                  trailing: app.packageName == current?.packageName
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(app),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
