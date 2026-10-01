import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/onboarding.dart';
import '../../providers.dart';
import '../../services/payment_gateway.dart';

/// Where a deep-link user lands after paying.
///
/// PLACEHOLDER: what this interface should contain has not been specified, so
/// it only confirms the purchase and shows what was submitted.
class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final LeadDetails? details = state.details;

    final Plan? plan = ref
        .watch(paymentGatewayProvider)
        .plans
        .where((Plan p) => p.id == state.planId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text("You're all set", style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              plan == null
                  ? 'Your plan is active.'
                  : '${plan.title} plan · ${plan.priceLabel}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          if (details != null) ...<Widget>[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Name'),
              subtitle: Text(details.name),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email'),
              subtitle: Text(details.email),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Phone'),
              subtitle: Text(details.phone),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Address'),
              subtitle: Text(details.address),
            ),
            const Divider(),
          ],
          // A released build has no way out of this interface. Developers
          // need one, or the only route back to the notes app is clearing
          // the app's data.
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextButton(
                onPressed: () =>
                    ref.read(onboardingControllerProvider.notifier).reset(),
                child: const Text('Reset deep-link flow (debug only)'),
              ),
            ),
        ],
      ),
    );
  }
}
