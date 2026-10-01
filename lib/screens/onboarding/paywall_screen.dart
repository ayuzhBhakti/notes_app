import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/payment_gateway.dart';
import '../../utils/errors.dart';

/// Second screen of the deep-link flow: choose a plan and pay.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  late String _selectedId = ref.read(paymentGatewayProvider).plans.first.id;

  void _back() =>
      ref.read(onboardingControllerProvider.notifier).editDetails();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PaymentGateway gateway = ref.watch(paymentGatewayProvider);
    final AsyncValue<void> purchase = ref.watch(purchaseControllerProvider);
    final bool busy = purchase.isLoading;
    final Plan selected =
        gateway.plans.firstWhere((Plan p) => p.id == _selectedId);
    final String firstName = (ref.watch(onboardingControllerProvider).details?.name ?? '')
        .split(RegExp(r'\s+'))
        .first;

    // The paywall is the root route, so an unhandled system back would close
    // the app. Going back to the form is what a user expects instead.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop && !busy) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Semantics(
            identifier: 'paywall_back_button',
            child: IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.arrow_back),
              onPressed: busy ? null : _back,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.workspace_premium_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Choose your plan', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  firstName.isEmpty
                      ? 'Pick a plan to finish setting up.'
                      : 'Pick a plan to finish setting up, $firstName.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                for (final Plan plan in gateway.plans)
                  _PlanCard(
                    plan: plan,
                    selected: plan.id == _selectedId,
                    onTap: busy
                        ? null
                        : () => setState(() => _selectedId = plan.id),
                  ),
                if (gateway.isSimulated) ...<Widget>[
                  const SizedBox(height: 4),
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
                          'Test mode: no payment is taken.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (purchase.hasError) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    describeError(purchase.error!).message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => ref
                            .read(purchaseControllerProvider.notifier)
                            .purchase(selected),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Subscribe for ${selected.priceLabel}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        identifier: 'paywall_plan_${plan.id}',
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: selected ? theme.colorScheme.primaryContainer : null,
              border: Border.all(
                width: selected ? 2 : 1,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(plan.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        plan.caption,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(plan.priceLabel, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
