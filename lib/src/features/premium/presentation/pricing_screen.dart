import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../auth/data/auth_repository.dart';
import '../data/premium_repository.dart';
import '../domain/premium_plan.dart';

/// Full paywall (D41): benefits, monthly/yearly plan cards with the 7-day
/// free trial, restore, and the current premium status. Opened from every
/// former "Upgrade screen coming soon!" dead end.
class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  String? _selectedPlanId = kPremiumYearlyProductId;
  bool _busy = false;

  PremiumPlan get _selectedPlan => kPremiumPlans.firstWhere(
    (plan) => plan.productId == _selectedPlanId,
    orElse: () => kPremiumPlans.first,
  );

  @override
  void initState() {
    super.initState();
    final repository = ref.read(premiumRepositoryProvider);
    if (repository.storeSupported) {
      _purchases = repositoryPurchaseStream.listen(_onPurchasesChanged);
    }
  }

  Stream<List<PurchaseDetails>> get repositoryPurchaseStream =>
      InAppPurchase.instance.purchaseStream;

  @override
  void dispose() {
    _purchases?.cancel();
    super.dispose();
  }

  Future<void> _onPurchasesChanged(List<PurchaseDetails> purchases) async {
    final repository = ref.read(premiumRepositoryProvider);
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          setState(() => _busy = true);
          try {
            await repository.verify(purchase);
            await repository.complete(purchase);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome to Premium! 🎉')),
              );
              Navigator.of(context).pop(true);
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not verify purchase: $error')),
              );
            }
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        case PurchaseStatus.pending:
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Purchase pending…')));
          }
        case PurchaseStatus.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  purchase.error?.message ?? 'The purchase failed.',
                ),
              ),
            );
          }
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  Future<void> _buySelected() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(premiumRepositoryProvider).buy(_selectedPlan);
      // Result arrives on the purchase stream.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(premiumRepositoryProvider).restore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Checking for previous purchases… nothing to restore '
              'will show no change.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final isPremium = user?.isPremium ?? false;
    final premiumUntil = user?.premiumUntil;
    final prices = ref.watch(premiumPricesProvider).value ?? const {};
    final theme = Theme.of(context);
    final savings = yearlySavingsPercent(kPremiumPlans);

    return Scaffold(
      appBar: AppBar(title: const Text('EquiSplit Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isPremium) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          premiumUntil == null
                              ? 'Premium is active on your account.'
                              : 'Premium active until '
                                    '${premiumUntil.year}-${premiumUntil.month.toString().padLeft(2, '0')}-${premiumUntil.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Get more out of EquiSplit',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._benefits(theme),
            const SizedBox(height: 24),
            Text(
              'Choose your plan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final plan in kPremiumPlans) ...[
                    Expanded(child: _buildPlanCard(theme, plan, prices)),
                    if (plan != kPremiumPlans.last) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (savings > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Yearly saves you $savings% compared to paying monthly.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _buySelected,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.workspace_premium),
              label: const Text('Start 7-day free trial'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Restore purchases'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Free for 7 days, then auto-renews until cancelled in Google '
              'Play. Cancel anytime. Purchases and premium are handled by '
              'Google Play Billing; support keeps your data in sync.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _benefits(ThemeData theme) {
    const benefits = [
      (
        Icons.person,
        'Personal expenses group',
        'Track private spending and cash inflows in your own space',
      ),
      (
        Icons.category,
        'Custom categories',
        'Create categories that fit how you spend',
      ),
      (
        Icons.block,
        'Ad-free experience',
        'No interstitials while adding expenses',
      ),
    ];
    return [
      for (final (icon, title, subtitle) in benefits)
        ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          contentPadding: EdgeInsets.zero,
        ),
    ];
  }

  Widget _buildPlanCard(
    ThemeData theme,
    PremiumPlan plan,
    Map<String, String> prices,
  ) {
    final selected = plan.productId == _selectedPlanId;
    final price = priceFor(plan, prices);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedPlanId = plan.productId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (plan.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan.badge!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              price,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(plan.periodLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              plan.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
