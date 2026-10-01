import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/onboarding.dart';
import '../../providers.dart';
import '../../utils/errors.dart';
import '../../utils/validators.dart';

/// First screen for a user who opened an onboarding link.
class DetailsFormScreen extends ConsumerStatefulWidget {
  const DetailsFormScreen({super.key});

  @override
  ConsumerState<DetailsFormScreen> createState() => _DetailsFormScreenState();
}

class _DetailsFormScreenState extends ConsumerState<DetailsFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  // Pre-filled when the user comes back from the paywall to edit.
  late final LeadDetails? _saved =
      ref.read(onboardingControllerProvider).details;
  late final TextEditingController _name =
      TextEditingController(text: _saved?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: _saved?.email ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: _saved?.phone ?? '');
  late final TextEditingController _address =
      TextEditingController(text: _saved?.address ?? '');

  /// Errors appear only after the first attempt to continue. Validating from
  /// the first keystroke would show "Enter a valid email" while it is typed.
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (ref.read(detailsSubmitControllerProvider).isLoading) return;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    // Saves to the server, then advances the stage. No navigation here:
    // AppGate reacts to the stage change, and a failure is rendered from the
    // provider below.
    ref.read(detailsSubmitControllerProvider.notifier).submit(
          LeadDetails(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<void> submit = ref.watch(detailsSubmitControllerProvider);
    final bool busy = submit.isLoading;
    final AppFailure? failure =
        submit.hasError ? describeError(submit.error!) : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _form,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tell us about you',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We need a few details before you choose a plan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Field(
                    identifier: 'onboarding_name_field',
                    controller: _name,
                    label: 'Full name',
                    icon: Icons.person_outline,
                    validator: validateName,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const <String>[AutofillHints.name],
                  ),
                  _Field(
                    identifier: 'onboarding_email_field',
                    controller: _email,
                    label: 'Email',
                    icon: Icons.mail_outline,
                    validator: validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                  ),
                  _Field(
                    identifier: 'onboarding_phone_field',
                    controller: _phone,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    validator: validatePhone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const <String>[
                      AutofillHints.telephoneNumber,
                    ],
                  ),
                  _Field(
                    identifier: 'onboarding_address_field',
                    controller: _address,
                    label: 'Address',
                    icon: Icons.home_outlined,
                    validator: validateAddress,
                    keyboardType: TextInputType.streetAddress,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const <String>[
                      AutofillHints.fullStreetAddress,
                    ],
                    maxLines: 3,
                    // The last field submits; the others move focus on.
                    textInputAction: TextInputAction.done,
                    onSubmitted: _submit,
                  ),
                  if (failure != null) ...<Widget>[
                    Text(
                      failure.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    if (failure.hint != null)
                      Text(
                        failure.hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.identifier,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    required this.keyboardType,
    required this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  /// What the Maestro flows select on; a label is not a stable selector once
  /// the field has content.
  final String identifier;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType keyboardType;
  final List<String> autofillHints;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        identifier: identifier,
        child: TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          maxLines: maxLines,
          textInputAction: textInputAction,
          onFieldSubmitted:
              onSubmitted == null ? null : (String _) => onSubmitted!(),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
    );
  }
}
