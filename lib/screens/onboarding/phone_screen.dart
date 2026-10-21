import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/country.dart';
import '../../models/remote_config.dart';
import '../../providers.dart';
import '../../services/evos_backend.dart';
import '../../utils/errors.dart';
import '../../utils/validators.dart';
import '../../widgets/brand.dart';

/// First screen of the deep-link flow: the mobile number a sign-in code is
/// sent to. One screen for new and returning users; a new number becomes an
/// account when its code is verified.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  // Pre-filled after "Change number" on the code screen.
  late final TextEditingController _phone = TextEditingController(
    text: ref.read(phoneAuthControllerProvider).lastPhone ?? '',
  );
  // Kept after "Change number", like the number itself.
  late Country _country = ref.read(phoneAuthControllerProvider).country;

  /// The longest a fresh install waits for the backend's settings and the
  /// first slide before showing the form anyway.
  static const Duration _maxWait = Duration(seconds: 4);

  // False only on a first launch, while the settings have not answered or
  // the first slide image has not loaded. Drawing the form then would show
  // it without the carousel, focus the field and open the keyboard, and the
  // carousel arriving a moment later would rearrange the screen and stay
  // hidden behind that keyboard. Once true it stays true.
  bool _ready = false;
  Timer? _readyTimer;
  // The first slide already being loaded, so each is started once.
  String? _warmed;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).phoneEntryViewed();
    _readyTimer = Timer(_maxWait, _showForm);
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  void _showForm() {
    _readyTimer?.cancel();
    if (mounted && !_ready) setState(() => _ready = true);
  }

  /// Loads every slide image into the image cache, at the size the carousel
  /// draws it, and shows the form once the first one is in. A failed image
  /// counts as in: the carousel shows its placeholder for it.
  ///
  /// True when the first one was already in the cache, as after "Change
  /// number": the form then shows on this frame, with no flash of spinner.
  bool _warmSlides(List<LoginSlide> slides) {
    if (_warmed == slides.first.imageUrl) return false;
    _warmed = slides.first.imageUrl;
    for (final LoginSlide slide in slides.skip(1)) {
      precacheImage(
        _slideImage(context, slide.imageUrl),
        context,
        onError: (Object _, StackTrace? _) {},
      );
    }

    // The first by hand rather than through precacheImage, whose future
    // completes a microtask late even for a cached image.
    bool inBuild = true;
    bool loadedNow = false;
    final ImageStream stream = _slideImage(
      context,
      slides.first.imageUrl,
    ).resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    void loaded() {
      // Removed after the frame, as precacheImage does, so the cache has
      // taken the image before its last listener goes.
      SchedulerBinding.instance.addPostFrameCallback(
        (Duration _) => stream.removeListener(listener),
      );
      if (inBuild) {
        loadedNow = true;
      } else {
        _showForm();
      }
    }

    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        image.dispose();
        loaded();
      },
      onError: (Object _, StackTrace? _) => loaded(),
    );
    stream.addListener(listener);
    inBuild = false;
    return loadedNow;
  }

  void _submit() {
    final String? phone = normalizeNationalNumber(_country, _phone.text);
    if (phone == null) return;
    FocusScope.of(context).unfocus();
    ref.read(phoneAuthControllerProvider.notifier).requestCode(_country, phone);
  }

  Future<void> _pickCountry() async {
    final Country? picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) => _CountrySheet(current: _country),
    );
    if (picked == null || picked == _country || !mounted) return;
    setState(() => _country = picked);
    // A number typed for one country is rarely right for another: India's
    // field holds ten digits, others up to fourteen.
    if (normalizeNationalNumber(picked, _phone.text) == null) _phone.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final PhoneAuthState auth = ref.watch(phoneAuthControllerProvider);
    final bool testMode =
        kDebugMode && ref.watch(evosBackendProvider) is UnconfiguredEvosBackend;
    final String appName = ref.watch(
      remoteConfigProvider.select((RemoteConfig c) => c.appName),
    );
    final List<LoginSlide> slides = ref.watch(
      remoteConfigProvider.select((RemoteConfig c) => c.loginSlides),
    );
    final bool hasSlides = slides.isNotEmpty;
    if (!_ready && ref.watch(remoteConfigSettledProvider)) {
      if (!hasSlides || _warmSlides(slides)) {
        _readyTimer?.cancel();
        _ready = true;
      }
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Read above the Scaffold, which hides the keyboard's height from its body.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // As on CashAlert, the carousel steps aside while the number is typed.
    final bool showCarousel = hasSlides && !keyboardOpen;

    final Widget form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // With a carousel the brand is already in the header above it.
        if (!hasSlides) ...<Widget>[
          const Align(alignment: Alignment.centerLeft, child: BrandLogo()),
          const SizedBox(height: 28),
        ],
        Text(
          'Welcome to $appName',
          style: (hasSlides
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your mobile number to sign in or create your account.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          identifier: 'phone_field',
          label: 'Mobile number',
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _phone,
            builder: (BuildContext context, TextEditingValue value, Widget? _) =>
                _PhoneField(
              controller: _phone,
              country: _country,
              onPickCountry: auth.busy ? null : _pickCountry,
              // Not with a carousel: the keyboard would hide it at once.
              autofocus: !hasSlides,
              enabled: !auth.busy,
              onSubmitted: _submit,
              // Only once ten digits are in: an error while the number is
              // still being typed is noise.
              errorText: _country.isIndia
                  ? (value.text.length == 10
                      ? validateIndianMobile(value.text)
                      : null)
                  // Elsewhere the length is not known, so nothing is called
                  // wrong until it is too long to be a number at all.
                  : (value.text.length > 15 - _country.dialCode.length
                      ? validateNationalNumber(_country, value.text)
                      : null),
            ),
          ),
        ),
        if (auth.error != null) ...<Widget>[
          const SizedBox(height: 12),
          _ErrorText(error: auth.error!),
        ],
        // Said before "Send code", not only after: it is what tells a tester,
        // and the end-to-end flow, that no real number is about to be texted.
        if (testMode) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.science_outlined, size: 18, color: colors.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Test mode: no SMS is sent.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Right under the field it fills in, not pinned to the screen's foot.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _phone,
          builder: (BuildContext context, TextEditingValue value, Widget? _) =>
              Semantics(
            identifier: 'send_code_button',
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: auth.busy ||
                        normalizeNationalNumber(_country, value.text) == null
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: auth.busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Send code'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "We'll send a 6-digit code by SMS.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasSlides) ...<Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandHeader(),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: hasSlides
                    // The form keeps the same place in this tree whether the
                    // carousel shows or not. Moving it would drop the field's
                    // focus, close the keyboard, bring the carousel back, and
                    // so on.
                    ? LayoutBuilder(
                        builder: (
                          BuildContext context,
                          BoxConstraints constraints,
                        ) =>
                            Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // All the room the form does not need.
                            Expanded(
                              child: showCarousel
                                  ? _LoginCarousel(slides: slides)
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(height: showCarousel ? 24 : 0),
                            // Its own height, scrolling only when the
                            // keyboard leaves less than that.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight,
                              ),
                              child: SingleChildScrollView(child: form),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 20),
                        child: form,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The number field: the country, as its flag and calling code, always in
/// view and tappable to change, then the number.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onPickCountry,
    required this.autofocus,
    required this.enabled,
    required this.onSubmitted,
    required this.errorText,
  });

  final TextEditingController controller;
  final Country country;

  /// Null while a code is being sent.
  final VoidCallback? onPickCountry;
  final bool autofocus;
  final bool enabled;
  final VoidCallback onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? digits = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: width == 0
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const <String>[AutofillHints.telephoneNumberNational],
      inputFormatters: country.isIndia
          ? const <TextInputFormatter>[_IndianMobileFormatter()]
          : <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15 - country.dialCode.length),
            ],
      onSubmitted: (String _) => onSubmitted(),
      style: digits,
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: country.isIndia ? '98765 43210' : 'Mobile number',
        hintStyle: digits?.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.45),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                identifier: 'country_picker',
                button: true,
                label: 'Country: ${country.name}, +${country.dialCode}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onPickCountry,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(country.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text('+${country.dialCode}', style: digits),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colors.outlineVariant,
                ),
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        border: border(colors.outline, 0),
        enabledBorder: border(colors.outline, 0),
        disabledBorder: border(colors.outline, 0),
        focusedBorder: border(colors.primary, 2),
        errorBorder: border(colors.error, 1.5),
        focusedErrorBorder: border(colors.error, 2),
        errorText: errorText,
      ),
    );
  }
}

/// Every country, searchable by name, calling code or ISO code.
class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.current});

  final Country current;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  List<Country> get _matches {
    final String q = _query.trim().toLowerCase().replaceFirst('+', '');
    if (q.isEmpty) return kCountries;
    return <Country>[
      for (final Country c in kCountries)
        if (c.name.toLowerCase().contains(q) ||
            c.dialCode.startsWith(q) ||
            c.isoCode.toLowerCase() == q)
          c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<Country> matches = _matches;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        // Keeps the search field above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Choose your country',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (String value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No country matches "$_query".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Country c = matches[i];
                        final bool selected = c == widget.current;
                        return ListTile(
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            c.name,
                            style: selected
                                ? const TextStyle(fontWeight: FontWeight.w700)
                                : null,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '+${c.dialCode}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (selected) ...<Widget>[
                                const SizedBox(width: 8),
                                Icon(Icons.check_rounded, color: colors.primary),
                              ],
                            ],
                          ),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The CashAlert login carousel, as one card: the backend's images edge to
/// edge, the slide's title over a soft shade at the foot, and a dot per slide.
/// Moves on by itself every two seconds and can be swiped.
class _LoginCarousel extends StatefulWidget {
  const _LoginCarousel({required this.slides});

  final List<LoginSlide> slides;

  static const Duration interval = Duration(seconds: 2);

  @override
  State<_LoginCarousel> createState() => _LoginCarouselState();
}

class _LoginCarouselState extends State<_LoginCarousel> {
  final PageController _pages = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(_LoginCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The backend's list can shrink when the settings are refreshed.
    if (_index >= widget.slides.length) {
      _index = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Started again after every page change, so a swipe gets a full two
  /// seconds before the next automatic one.
  void _restartTimer() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer(_LoginCarousel.interval, () {
      if (!_pages.hasClients) return;
      _pages.animateToPage(
        (_index + 1) % widget.slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = widget.slides[_index].title;
    final bool manySlides = widget.slides.length > 1;

    return Semantics(
      identifier: 'login_carousel',
      label: title.isEmpty ? null : title,
      child: DecoratedBox(
        // A soft stage in the brand's colour, so a screenshot with a white
        // background still reads as a phone screen and not as a blank.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          // A tint of the brand colour rather than its container colour,
          // which the fidelity scheme makes nearly as strong as the brand
          // itself: dark text on it, and a dark screenshot, both stay legible.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(
                colors.primary.withValues(alpha: 0.07),
                colors.surface,
              ),
              Color.alphaBlend(
                colors.primary.withValues(alpha: 0.16),
                colors.surface,
              ),
            ],
          ),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: SizedBox(
                // Room for two lines always, so the screenshots do not jump
                // between a one-line and a two-line title.
                height: 56,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      title,
                      key: ValueKey<int>(_index),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                // Keeps the next screenshot built, so it has loaded by the
                // time it slides in.
                allowImplicitScrolling: true,
                itemCount: widget.slides.length,
                onPageChanged: (int index) {
                  setState(() => _index = index);
                  _restartTimer();
                },
                itemBuilder: (BuildContext context, int index) => Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: _Screenshot(
                    image: _slideImage(context, widget.slides[index].imageUrl),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: manySlides
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < widget.slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                            width: i == _index ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? colors.primary
                                  : colors.primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A slide image, decoded at a height worked out from the screen rather than
/// the file: a full-resolution screenshot would cost tens of megabytes of
/// memory for a card this size. From the screen and not the card, so the copy
/// [_PhoneScreenState] loads before the carousel shows is the one it draws:
/// the image cache keys on the decode size.
ImageProvider _slideImage(BuildContext context, String url) {
  // The card is never taller than about half the screen.
  final double height =
      MediaQuery.sizeOf(context).height *
      0.6 *
      MediaQuery.devicePixelRatioOf(context);
  return ResizeImage.resizeIfNeeded(null, height.round(), NetworkImage(url));
}

/// One app screenshot, shown whole with a phone screen's rounded corners
/// and a soft shadow. Never cropped: it is the app being shown.
class _Screenshot extends StatelessWidget {
  const _Screenshot({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    // Phone-shaped, while the real picture loads or if it cannot.
    final Widget placeholder = AspectRatio(
      aspectRatio: 9 / 19.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Center(
          child: Icon(
            Icons.smartphone_rounded,
            size: 36,
            color: colors.primary.withValues(alpha: 0.25),
          ),
        ),
      ),
    );

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image(
            image: image,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            loadingBuilder:
                (BuildContext _, Widget image, ImageChunkEvent? progress) =>
                    progress == null ? image : placeholder,
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                placeholder,
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

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
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// Keeps the field to the ten digits of the number. A pasted or auto-filled
/// number often arrives as `+91 98765 43210` or `09876543210`; cutting that
/// at ten characters would keep the wrong ten.
class _IndianMobileFormatter extends TextInputFormatter {
  const _IndianMobileFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Only for text that arrived in one go. An eleventh digit typed after a
    // number that happens to start with 91 must not eat its first two.
    final bool arrivedWhole = newValue.text.length - oldValue.text.length > 1;
    if (arrivedWhole && digits.length > 10) {
      if (digits.startsWith('91')) {
        digits = digits.substring(2);
      } else if (digits.startsWith('0')) {
        digits = digits.substring(1);
      }
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
