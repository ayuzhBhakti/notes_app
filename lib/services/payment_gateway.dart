/// One purchasable option on the paywall.
class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.caption,
  });

  final String id;
  final String title;

  /// Already formatted for display. A real gateway gets this from the store,
  /// which localises the currency.
  final String priceLabel;
  final String caption;
}

/// The user backed out of the payment sheet. Never shown as an error.
class PaymentCanceled implements Exception {
  const PaymentCanceled();

  @override
  String toString() => 'PaymentCanceled';
}

/// The seam between the paywall and whoever takes the money. The screens know
/// only this interface, so a real provider replaces [SimulatedPaymentGateway]
/// by changing one provider.
abstract class PaymentGateway {
  /// True when no real payment is taken. The paywall says so on screen.
  bool get isSimulated;

  List<Plan> get plans;

  /// Completes on success, throws [PaymentCanceled] if the user backs out, and
  /// throws anything else on failure.
  Future<void> purchase(Plan plan);
}

/// Stands in until a real provider is chosen. Every purchase succeeds, nothing
/// is charged, and nothing is verified: the resulting entitlement is only a
/// flag on the device.
class SimulatedPaymentGateway implements PaymentGateway {
  const SimulatedPaymentGateway({
    this.delay = const Duration(milliseconds: 1200),
  });

  /// Long enough for the paywall's busy state to be visible.
  final Duration delay;

  @override
  bool get isSimulated => true;

  // Placeholder catalogue. Titles and prices are not real products.
  @override
  List<Plan> get plans => const <Plan>[
        Plan(
          id: 'yearly',
          title: 'Yearly',
          priceLabel: '₹1,499 / year',
          caption: 'Best value',
        ),
        Plan(
          id: 'monthly',
          title: 'Monthly',
          priceLabel: '₹199 / month',
          caption: 'Cancel anytime',
        ),
      ];

  @override
  Future<void> purchase(Plan plan) => Future<void>.delayed(delay);
}
