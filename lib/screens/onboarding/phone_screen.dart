import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).phoneEntryViewed();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final String? phone = normalizeIndianMobile(_phone.text);
    if (phone == null) return;
    FocusScope.of(context).unfocus();
    ref.read(phoneAuthControllerProvider.notifier).requestCode(phone);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PhoneAuthState auth = ref.watch(phoneAuthControllerProvider);
    final bool testMode =
        kDebugMode && ref.watch(evosBackendProvider) is UnconfiguredEvosBackend;
    final String appName = ref.watch(
      remoteConfigProvider.select((RemoteConfig c) => c.appName),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const BrandLogo(),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to $appName',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your mobile number. We'll text you a 6-digit "
                        'code to sign in or create your account.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Semantics(
                        identifier: 'phone_field',
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _phone,
                          builder: (
                            BuildContext context,
                            TextEditingValue value,
                            Widget? _,
                          ) =>
                              TextField(
                            controller: _phone,
                            autofocus: true,
                            enabled: !auth.busy,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.telephoneNumberNational,
                            ],
                            inputFormatters: const <TextInputFormatter>[
                              _IndianMobileFormatter(),
                            ],
                            onSubmitted: (String _) => _submit(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              letterSpacing: 1.5,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            decoration: InputDecoration(
                              labelText: 'Mobile number',
                              prefixText: '+91  ',
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              // Only once ten digits are in: an error while
                              // the number is still being typed is noise.
                              errorText: value.text.length == 10
                                  ? validateIndianMobile(value.text)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      if (auth.error != null) ...<Widget>[
                        const SizedBox(height: 16),
                        _ErrorText(error: auth.error!),
                      ],
                      // Said before "Send code", not only after: it is what
                      // tells a tester, and the end-to-end flow, that no real
                      // number is about to be texted.
                      if (testMode) ...<Widget>[
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.science_outlined,
                              size: 18,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Test mode: no SMS is sent.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _phone,
                builder: (
                  BuildContext context,
                  TextEditingValue value,
                  Widget? _,
                ) =>
                    Semantics(
                  identifier: 'send_code_button',
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: auth.busy ||
                              normalizeIndianMobile(value.text) == null
                          ? null
                          : _submit,
                      child: auth.busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send code'),
                    ),
                  ),
                ),
              ),
              // A released build has no way out of this interface. Developers
              // need one, or the only route back to the notes app is clearing
              // the app's data.
              if (kDebugMode)
                Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(onboardingControllerProvider.notifier).reset(),
                    child: const Text('Reset deep-link flow (debug only)'),
                  ),
                ),
            ],
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
