import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService with ChangeNotifier {
  static final PurchaseService instance = PurchaseService._internal();
  PurchaseService._internal();
  factory PurchaseService() => instance;

  static const String _kProductIdPro = 'pro_lifetime';
  static const String _kEntitlementKey = 'entitlement_is_pro';

  final InAppPurchase _iap = InAppPurchase.instance;
  final Set<String> _productIds = {_kProductIdPro};

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;

  bool _isPro = false;
  bool get isPro => _isPro;

  ProductDetails? _proDetails;
  ProductDetails? get proDetails => _proDetails;

  Future<void> init() async {
    _available = await _iap.isAvailable();
    await _loadEntitlementFromLocal();

    if (_available) {
      final response = await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        debugPrint('Product query error: ${response.error}');
      }
      if (response.productDetails.isNotEmpty) {
        _proDetails = response.productDetails.firstWhere(
          (p) => p.id == _kProductIdPro,
          orElse: () => response.productDetails.first,
        );
        notifyListeners();
      }

      _sub?.cancel();
      _sub = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _sub?.cancel(),
        onError: (e) => debugPrint('purchaseStream error: $e'),
      );
    }
  }

  Future<void> disposeService() async {
    await _sub?.cancel();
  }

  Future<void> buyPro() async {
    final details = _proDetails;
    if (!_available || details == null) {
      throw Exception('ストアに接続できないか商品が見つかりません');
    }
    final param = PurchaseParam(productDetails: details);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _verifyPurchase(p);
          if (ok) {
            await _grantEntitlement();
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails p) async {
    // MVP: ローカル検証（本来はサーバー検証）
    return p.productID == _kProductIdPro;
  }

  Future<void> _grantEntitlement() async {
    _isPro = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEntitlementKey, true);
  }

  Future<void> _loadEntitlementFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kEntitlementKey) ?? false;
    notifyListeners();
  }
}
