/// Premium subscription plans sold through Google Play Billing (D41).
///
/// Product ids match the subscriptions created in Google Play Console for
/// `apk.equisplit.click`; prices are US$ fallbacks shown until the store
/// returns the localized price.
class PremiumPlan {
  const PremiumPlan({
    required this.productId,
    required this.title,
    required this.periodLabel,
    required this.fallbackPrice,
    required this.annualCost,
    this.badge,
  });

  /// Google Play subscription id.
  final String productId;

  /// Short display name ("Monthly" / "Yearly").
  final String title;

  /// Suffix under the price ("per month" / "per year").
  final String periodLabel;

  /// Fallback price in US$ until the store responds.
  final double fallbackPrice;

  /// What the plan costs over twelve months, for savings comparisons.
  final double annualCost;

  /// Optional highlight badge ("Best value").
  final String? badge;

  bool get isYearly => productId == kPremiumYearlyProductId;
}

const String kPremiumMonthlyProductId = 'equisplit_premium_monthly';
const String kPremiumYearlyProductId = 'equisplit_premium_yearly';

const List<PremiumPlan> kPremiumPlans = [
  PremiumPlan(
    productId: kPremiumMonthlyProductId,
    title: 'Monthly',
    periodLabel: 'per month',
    fallbackPrice: 2.99,
    annualCost: 35.88,
  ),
  PremiumPlan(
    productId: kPremiumYearlyProductId,
    title: 'Yearly',
    periodLabel: 'per year',
    fallbackPrice: 19.99,
    annualCost: 19.99,
    badge: 'Best value',
  ),
];

/// How much cheaper the yearly plan is versus twelve monthly payments, as a
/// whole percentage (0-100). Returns 0 when either plan is missing.
int yearlySavingsPercent(Iterable<PremiumPlan> plans) {
  double? monthlyAnnualCost;
  double? yearlyAnnualCost;
  for (final plan in plans) {
    if (plan.isYearly) {
      yearlyAnnualCost = plan.annualCost;
    } else {
      monthlyAnnualCost = plan.annualCost;
    }
  }
  if (monthlyAnnualCost == null ||
      yearlyAnnualCost == null ||
      monthlyAnnualCost <= 0) {
    return 0;
  }
  final savings = (monthlyAnnualCost - yearlyAnnualCost) / monthlyAnnualCost;
  return (savings * 100).round();
}

/// The price shown for [plan]: the localized store price when the store has
/// responded, otherwise the US$ fallback.
String priceFor(PremiumPlan plan, Map<String, String> storePrices) {
  return storePrices[plan.productId] ??
      '\$${plan.fallbackPrice.toStringAsFixed(2)}';
}
