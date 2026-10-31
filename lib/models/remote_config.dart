import 'dart:convert';
import 'dart:ui' show Color;

/// One page of the carousel on the mobile-number screen.
class LoginSlide {
  const LoginSlide({required this.imageUrl, this.title = ''});

  final String imageUrl;

  /// Shown above the images while this slide is showing. May be blank.
  final String title;
}

/// What the backend decides about the deep-link interface: its name, logo and
/// colour, the paywall's words and prices, and the web page subscribers see.
///
/// Built from the public rows of the `app_config` table. Every field has a
/// default, so a missing row, a blank value or no network at all still gives
/// a complete screen.
class RemoteConfig {
  const RemoteConfig({
    this.appName = 'Evos',
    this.logoUrl,
    this.seedColor = const Color(0xFF6D28D9),
    this.paywallTitlePrefix = '1-Day',
    this.paywallTitleBadge = '',
    this.paywallTitleSuffix = 'Trial',
    this.ratingValue = '',
    this.ratingCaption = '',
    this.previewImageUrl,
    this.previewVideoUrl,
    this.videoAspectRatio = 1,
    this.paywallSubtitle = '',
    this.features = const <String>[
      'Full access',
      'Cancel anytime',
      'Secure UPI AutoPay',
    ],
    this.featureIcons = const <String>[],
    this.showStrikePrice = false,
    this.accentColor,
    this.autoPayText = '',
    this.socialProofs = const <String>[],
    this.socialProofIcon = '',
    this.ctaText = 'Try Now',
    this.upiSelectText = 'Select UPI App',
    this.upiSheetTitle = 'Pay with UPI AutoPay',
    this.loginSlides = const <LoginSlide>[],
    this.webUrl,
    this.planId = '',
    this.planName = 'Evos Premium Monthly',
    this.trialAmount = 3,
    this.recurringAmount = 299,
  });

  final String appName;

  /// Null shows the first letter of [appName] on a tile instead.
  final String? logoUrl;

  /// The interface's whole colour scheme is generated from this one colour.
  final Color seedColor;

  /// The paywall heading is three parts: text, a filled pill, text.
  /// A blank [paywallTitleBadge] shows the trial price in the pill.
  final String paywallTitlePrefix;
  final String paywallTitleBadge;
  final String paywallTitleSuffix;

  /// Both blank by default, which hides the rating row. They are only ever
  /// what the backend sends: the app never invents a rating.
  final String ratingValue;
  final String ratingCaption;

  final String? previewImageUrl;

  /// Plays, looping, in the preview card, as on the CashAlert paywall. Wins
  /// over [previewImageUrl], which is shown instead if the video cannot play.
  final String? previewVideoUrl;

  /// Width over height of the preview video. The card is drawn at this shape
  /// from the first frame, because the video only reports its own shape once
  /// it has downloaded enough to play, and the card growing then pushed the
  /// price down. A video of another shape is fitted inside, never resized.
  final double videoAspectRatio;

  /// A line under the heading. Blank hides it.
  final String paywallSubtitle;

  /// At most four are shown.
  final List<String> features;

  /// One per feature, paired by position: an https image, or a name from the
  /// paywall's icon list. Blank, unknown or missing shows a tick.
  final List<String> featureIcons;

  /// The monthly price struck through beside the trial price. Off unless the
  /// backend sends `true` (owner's decision, 2026-10-31).
  final bool showStrikePrice;

  /// The pill, the large price and the icons. Null uses the theme colour.
  final Color? accentColor;

  /// The sentence that says money is taken every month. `{trial}` and
  /// `{recurring}` are replaced with the two prices, so the words cannot
  /// drift from what is charged. Blank uses [defaultAutoPayText].
  final String autoPayText;

  /// Lines rotated under the price. Empty hides the strip.
  final List<String> socialProofs;

  /// Same forms as [featureIcons]. Blank shows a sparkle.
  final String socialProofIcon;

  /// The bottom bar and the UPI app sheet.
  final String ctaText;
  final String upiSelectText;
  final String upiSheetTitle;

  /// The carousel above the mobile-number form, as on the CashAlert login
  /// screen. Empty hides it.
  final List<LoginSlide> loginSlides;

  /// The page a subscriber lands on, from the `webview_url` row. https only.
  /// Null shows a "come back soon" screen in its place.
  final String? webUrl;

  /// The Cashfree plan. Blank when the server describes the plan inline.
  /// The server reads its own copy when charging; this one is for analytics.
  final String planId;
  final String planName;

  /// Rupees. [trialAmount] is authorised today and covers the first 24 hours;
  /// [recurringAmount] is then debited every month.
  final double trialAmount;
  final double recurringAmount;

  static const String currencyCode = 'INR';

  /// The id reported to analytics for the plan.
  String get analyticsPlanId => planId.isEmpty ? 'monthly' : planId;

  String get trialPriceLabel => formatRupees(trialAmount);
  String get recurringPriceLabel => formatRupees(recurringAmount);

  /// Used whenever the backend sends no [autoPayText], so the paywall always
  /// says that money is taken every month.
  static const String defaultAutoPayText =
      '{trial} today for the first 24 hours, then {recurring} every month by '
      'UPI AutoPay. Cancel any time in your UPI app.';

  String get autoPayStatement =>
      (autoPayText.isEmpty ? defaultAutoPayText : autoPayText)
          .replaceAll('{trial}', trialPriceLabel)
          .replaceAll('{recurring}', recurringPriceLabel);

  /// The icon for feature [index]: blank when the backend has none for it.
  String featureIcon(int index) =>
      index < featureIcons.length ? featureIcons[index] : '';

  /// ₹3, ₹299, ₹2.50. No thousands separator: these are small amounts.
  static String formatRupees(double amount) => amount == amount.roundToDouble()
      ? '₹${amount.toStringAsFixed(0)}'
      : '₹${amount.toStringAsFixed(2)}';

  /// From `key -> value` rows. Unknown keys are ignored and bad values fall
  /// back to the default, so a typo in the table can never break a screen.
  factory RemoteConfig.fromRows(Map<String, String> rows) {
    const RemoteConfig d = RemoteConfig();
    String text(String key, String fallback) {
      final String value = rows[key]?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    // Unlike [text], blank is a real answer here: it hides that part.
    String optional(String key, String fallback) =>
        rows.containsKey(key) ? rows[key]!.trim() : fallback;

    bool isHttps(String text) {
      final Uri? uri = Uri.tryParse(text);
      return uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
    }

    String? url(String key) {
      final Uri? uri = Uri.tryParse(rows[key]?.trim() ?? '');
      // https only: Android blocks cleartext, and the image is the brand.
      return uri != null && uri.isScheme('https') && uri.host.isNotEmpty
          ? uri.toString()
          : null;
    }

    List<String> list(String key, List<String> fallback) {
      if (!rows.containsKey(key)) return fallback;
      return <String>[
        for (final String part in rows[key]!.split('|'))
          if (part.trim().isNotEmpty) part.trim(),
      ];
    }

    double amount(String key, double fallback) {
      final double? value = double.tryParse(rows[key]?.trim() ?? '');
      return value != null && value > 0 && value.isFinite ? value : fallback;
    }

    // `9:16`, `9/16` or `0.5625`. Kept between 1:4 and 4:1, so a typo can
    // neither squash the card flat nor make it fill the screen.
    double ratio(String key, double fallback) {
      final String value = rows[key]?.trim() ?? '';
      final List<String> parts = value.split(RegExp(r'[:/]'));
      double? result;
      if (parts.length == 2) {
        final double? w = double.tryParse(parts[0].trim());
        final double? h = double.tryParse(parts[1].trim());
        if (w != null && h != null && h > 0) result = w / h;
      } else {
        result = double.tryParse(value);
      }
      return result != null && result >= 0.25 && result <= 4
          ? result
          : fallback;
    }

    bool flag(String key, bool fallback) =>
        switch (rows[key]?.trim().toLowerCase()) {
          'true' || 'yes' || '1' => true,
          'false' || 'no' || '0' => false,
          _ => fallback,
        };

    // Kept blank where a part is blank, so a missing icon does not move the
    // later ones onto the wrong feature.
    List<String> paired(String key) => <String>[
          for (final String part in (rows[key] ?? '').split('|')) part.trim(),
        ];

    // Images and titles are two lists paired by position, so a bad image is
    // dropped only after pairing: dropping it first would hand every later
    // image the wrong title.
    List<LoginSlide> slides() {
      final List<String> images = (rows['login_slide_images'] ?? '').split('|');
      final List<String> titles = (rows['login_slide_titles'] ?? '').split('|');
      return <LoginSlide>[
        for (int i = 0; i < images.length; i++)
          if (isHttps(images[i].trim()))
            LoginSlide(
              imageUrl: images[i].trim(),
              title: i < titles.length ? titles[i].trim() : '',
            ),
      ];
    }

    final String appName = text('app_name', d.appName);
    return RemoteConfig(
      appName: appName,
      logoUrl: url('app_logo_url'),
      seedColor: parseColor(rows['theme_color']) ?? d.seedColor,
      paywallTitlePrefix: optional('paywall_title_prefix', d.paywallTitlePrefix),
      paywallTitleBadge: optional('paywall_title_badge', d.paywallTitleBadge),
      paywallTitleSuffix: optional('paywall_title_suffix', d.paywallTitleSuffix),
      ratingValue: optional('paywall_rating_value', d.ratingValue),
      ratingCaption: optional('paywall_rating_caption', d.ratingCaption),
      previewImageUrl: url('paywall_preview_image_url'),
      previewVideoUrl: url('paywall_video_url'),
      videoAspectRatio: ratio('paywall_video_aspect_ratio', d.videoAspectRatio),
      paywallSubtitle: optional('paywall_subtitle', d.paywallSubtitle),
      features: list('paywall_features', d.features).take(4).toList(),
      featureIcons: paired('paywall_feature_icons'),
      showStrikePrice: flag('paywall_show_strike_price', d.showStrikePrice),
      accentColor: parseColor(rows['paywall_accent_color']),
      autoPayText: optional('paywall_autopay_text', d.autoPayText),
      socialProofs: list('paywall_social_proofs', d.socialProofs),
      socialProofIcon: optional('paywall_social_proof_icon', d.socialProofIcon),
      ctaText: text('paywall_cta_text', d.ctaText),
      upiSelectText: text('paywall_upi_select_text', d.upiSelectText),
      upiSheetTitle: text('paywall_upi_sheet_title', d.upiSheetTitle),
      loginSlides: slides(),
      webUrl: url('webview_url'),
      planId: optional('cashfree_plan_id', d.planId),
      planName: text('plan_name', '$appName Premium Monthly'),
      trialAmount: amount('cashfree_trial_amount', d.trialAmount),
      recurringAmount: amount('cashfree_recurring_amount', d.recurringAmount),
    );
  }

  /// `#RRGGBB` or `RRGGBB`. Null for anything else.
  static Color? parseColor(String? source) {
    final String hex = (source ?? '').trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  }
}

/// The rows as fetched, kept on the device so the next start is already
/// branded before the network answers, and still is with no network.
String encodeConfigRows(Map<String, String> rows) => jsonEncode(rows);

/// Null for nothing saved or anything unreadable.
Map<String, String>? decodeConfigRows(String? source) {
  if (source == null) return null;
  try {
    final Map<String, dynamic> json = jsonDecode(source) as Map<String, dynamic>;
    return <String, String>{
      for (final MapEntry<String, dynamic> entry in json.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  } catch (_) {
    return null;
  }
}
