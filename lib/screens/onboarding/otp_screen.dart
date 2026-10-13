import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/evos_backend.dart';
import '../../utils/errors.dart';

/// Second screen of the deep-link flow: the 6-digit code from the SMS.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  static const int codeLength = 6;

  /// How long before another code can be asked for.
  static const int resendSeconds = 30;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _ticker;
  int _secondsLeft = OtpScreen.resendSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    _secondsLeft = OtpScreen.resendSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft -= 1);
    });
  }

  void _onChanged(String value) {
    setState(() {});
    // No button press needed: the sixth digit is the user saying "done".
    if (value.length == OtpScreen.codeLength) _verify();
  }

  void _verify() {
    if (_code.text.length != OtpScreen.codeLength) return;
    ref.read(phoneAuthControllerProvider.notifier).verify(_code.text);
  }

  void _back() => ref.read(phoneAuthControllerProvider.notifier).changeNumber();

  @override
  Widget build(BuildContext context) {
    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (
      PhoneAuthState? previous,
      PhoneAuthState next,
    ) {
      // A wrong code is retyped from the start, so the boxes are emptied.
      final Object? error = next.error;
      if (previous != null &&
          previous.busy &&
          error is BackendFailure &&
          error.kind == BackendError.wrongCode) {
        _code.clear();
        _focus.requestFocus();
      }
      if (previous != null && next.sends > previous.sends) {
        setState(_startCountdown);
      }
    });

    final ThemeData theme = Theme.of(context);
    final PhoneAuthState auth = ref.watch(phoneAuthControllerProvider);
    final String phone = auth.phone ?? '';
    final String shown = phone.length == 10
        ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}'
        : '+91 $phone';
    final bool testMode =
        kDebugMode && ref.watch(evosBackendProvider) is UnconfiguredEvosBackend;

    // This is the root route, so an unhandled system back would close the
    // app. Going back to the number is what a user expects instead.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop && !auth.busy) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Change number',
            icon: const Icon(Icons.arrow_back),
            onPressed: auth.busy ? null : _back,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Enter the code',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sent by SMS to $shown',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _CodeBoxes(
                          controller: _code,
                          focusNode: _focus,
                          enabled: !auth.busy,
                          hasError: auth.error != null,
                          onChanged: _onChanged,
                        ),
                        if (auth.error != null) ...<Widget>[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _message(auth.error!),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_secondsLeft > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Resend code in '
                              '0:${_secondsLeft.toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          )
                        else
                          Semantics(
                            identifier: 'otp_resend_button',
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: auth.busy
                                  ? null
                                  : () => ref
                                      .read(
                                        phoneAuthControllerProvider.notifier,
                                      )
                                      .resend(),
                              child: const Text('Resend code'),
                            ),
                          ),
                        if (testMode) ...<Widget>[
                          const SizedBox(height: 8),
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
                                  'Test mode: no SMS is sent. The code is '
                                  '${UnconfiguredEvosBackend.debugCode}.',
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
                Semantics(
                  identifier: 'otp_verify_button',
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: auth.busy ||
                              _code.text.length != OtpScreen.codeLength
                          ? null
                          : _verify,
                      child: auth.busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _message(Object error) {
    final AppFailure failure = describeError(error);
    return failure.hint == null
        ? failure.message
        : '${failure.message} ${failure.hint}';
  }
}

/// Six boxes that are really one text field.
///
/// One field, drawn invisibly over the boxes, is what makes paste, the
/// keyboard's "from Messages" suggestion and backspace all behave. Six
/// separate fields handle none of the three well.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Stack(
      children: <Widget>[
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[controller, focusNode]),
          builder: (BuildContext context, Widget? _) {
            final String code = controller.text;
            return ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < OtpScreen.codeLength; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: 2,
                            color: hasError && code.isEmpty
                                ? colors.error
                                // The box the next digit goes into.
                                : focusNode.hasFocus && i == code.length
                                    ? colors.primary
                                    : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        Positioned.fill(
          child: Semantics(
            identifier: 'otp_field',
            label: '6-digit code',
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                enabled: enabled,
                keyboardType: TextInputType.number,
                // Lets the keyboard offer the code straight from the SMS.
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(OtpScreen.codeLength),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
