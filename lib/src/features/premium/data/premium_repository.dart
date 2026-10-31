import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/firebase/firestore_refs.dart';
import '../../../shared/utils/platform_info.dart';
import '../domain/premium_plan.dart';

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  return PremiumRepository(
    ref.watch(firebaseFunctionsProvider),
    InAppPurchase.instance,
  );
});

/// Localized store prices for [kPremiumPlans], keyed by product id. Empty
/// while loading, offline, or on platforms without the store; the paywall
/// then falls back to [PremiumPlan.fallbackPrice] (D41).
final premiumPricesProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(premiumRepositoryProvider).loadPrices(),
);

class PremiumRepository {
  PremiumRepository(this._functions, this._iap);

  final FirebaseFunctions _functions;
  final InAppPurchase _iap;

  /// Play Billing is Android-only for now (D41); other platforms keep
  /// manual grants and the paywall explains this.
  bool get storeSupported => PlatformInfo.isAndroid;

  /// Localized store prices keyed by product id; empty when the store is
  /// unavailable so callers fall back to the plan defaults.
  Future<Map<String, String>> loadPrices() async {
    if (!storeSupported) return const {};
    try {
      if (!await _iap.isAvailable()) return const {};
      final response = await _iap.queryProductDetails(
        kPremiumPlans.map((plan) => plan.productId).toSet(),
      );
      return {
        for (final product in response.productDetails)
          product.id: product.price,
      };
    } catch (_) {
      // Store errors (offline, Play services missing) are not fatal here —
      // the paywall shows fallback prices instead.
      return const {};
    }
  }

  /// Starts the purchase flow for [plan]. Purchase results arrive on
  /// [InAppPurchase.purchaseStream], which the paywall listens to.
  Future<void> buy(PremiumPlan plan) async {
    if (!storeSupported) {
      throw StateError(
        'Premium purchases are only available on Android right now.',
      );
    }
    if (!await _iap.isAvailable()) {
      throw StateError('The Google Play store is not available.');
    }
    final response = await _iap.queryProductDetails({plan.productId});
    final product = response.productDetails
        .where((details) => details.id == plan.productId)
        .firstOrNull;
    if (product == null) {
      throw StateError('The "${plan.title}" plan is not available.');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// Re-delivers past purchases on [InAppPurchase.purchaseStream] so
  /// reinstalls restore premium after verification.
  Future<void> restore() async {
    if (!storeSupported) return;
    await _iap.restorePurchases();
  }

  /// Server-side verification (D41): the `verifyPremiumPurchase` callable
  /// checks the token with the Play Developer API and grants premium until
  /// the subscription's expiry. `serverVerificationData` is the Android
  /// purchase token.
  Future<void> verify(PurchaseDetails purchase) {
    return _functions.httpsCallable('verifyPremiumPurchase').call<dynamic>({
      'productId': purchase.productID,
      'purchaseToken': purchase.verificationData.serverVerificationData,
    });
  }

  /// Acknowledges the purchase with Play; call after [verify] succeeds.
  Future<void> complete(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }
}
