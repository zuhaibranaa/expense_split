import 'package:equisplit/src/features/premium/domain/premium_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kPremiumPlans', () {
    test('defines the two Play subscription plans (D41)', () {
      expect(kPremiumPlans.map((plan) => plan.productId), [
        'equisplit_premium_monthly',
        'equisplit_premium_yearly',
      ]);
      expect(kPremiumPlans.first.isYearly, isFalse);
      expect(kPremiumPlans.last.isYearly, isTrue);
      expect(kPremiumPlans.last.badge, 'Best value');
    });

    test(
      'prices the yearly plan at roughly 44% off twelve monthly payments',
      () {
        expect(kPremiumPlans.first.annualCost, closeTo(2.99 * 12, 0.01));
        expect(yearlySavingsPercent(kPremiumPlans), 44);
      },
    );
  });

  group('yearlySavingsPercent', () {
    test('returns zero when a plan is missing', () {
      expect(yearlySavingsPercent([kPremiumPlans.first]), 0);
      expect(yearlySavingsPercent([kPremiumPlans.last]), 0);
      expect(yearlySavingsPercent(const []), 0);
    });

    test('returns zero when the yearly plan is not cheaper', () {
      const samePrice = [
        PremiumPlan(
          productId: kPremiumMonthlyProductId,
          title: 'Monthly',
          periodLabel: 'per month',
          fallbackPrice: 2.99,
          annualCost: 19.99,
        ),
        PremiumPlan(
          productId: kPremiumYearlyProductId,
          title: 'Yearly',
          periodLabel: 'per year',
          fallbackPrice: 19.99,
          annualCost: 19.99,
        ),
      ];
      expect(yearlySavingsPercent(samePrice), 0);
    });
  });

  group('priceFor', () {
    test('prefers the localized store price', () {
      expect(
        priceFor(kPremiumPlans.first, {kPremiumMonthlyProductId: 'PKR 850.00'}),
        'PKR 850.00',
      );
    });

    test('falls back to the USD price until the store responds', () {
      expect(priceFor(kPremiumPlans.first, const {}), r'$2.99');
      expect(priceFor(kPremiumPlans.last, const {}), r'$19.99');
    });
  });
}
