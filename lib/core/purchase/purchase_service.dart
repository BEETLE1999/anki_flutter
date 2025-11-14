// // lib/core/purchase/purchase_service.dart
//
// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class PurchaseService with ChangeNotifier {
//   static final PurchaseService instance = PurchaseService._internal();
//   PurchaseService._internal();
//   factory PurchaseService() => instance;
//
//   static const String _kProductIdPro = 'pro_lifetime';
//   static const String _kEntitlementKey = 'entitlement_is_pro';
//
//   final InAppPurchase _iap = InAppPurchase.instance;
//   final Set<String> _productIds = {_kProductIdPro};
//
//   StreamSubscription<List<PurchaseDetails>>? _sub;
//   bool _available = false;
//
//   bool _isPro = false;
//   bool get isPro => _isPro;
//
//   ProductDetails? _proDetails;
//   ProductDetails? get proDetails => _proDetails;
//
//   Future<void> init() async {
//     _available = await _iap.isAvailable();
//     await _loadEntitlementFromLocal();
//
//     if (_available) {
//       final response = await _iap.queryProductDetails(_productIds);
//       if (response.error != null) {
//         debugPrint('Product query error: ${response.error}');
//       }
//       if (response.productDetails.isNotEmpty) {
//         _proDetails = response.productDetails.firstWhere(
//           (p) => p.id == _kProductIdPro,
//           orElse: () => response.productDetails.first,
//         );
//         notifyListeners();
//       }
//
//       _sub?.cancel();
//       _sub = _iap.purchaseStream.listen(
//         _onPurchaseUpdate,
//         onDone: () => _sub?.cancel(),
//         onError: (e) => debugPrint('purchaseStream error: $e'),
//       );
//     }
//   }
//
//   Future<void> disposeService() async {
//     await _sub?.cancel();
//   }
//
//   Future<void> buyPro() async {
//     final details = _proDetails;
//     if (!_available || details == null) {
//       throw Exception('ストアに接続できないか商品が見つかりません');
//     }
//     final param = PurchaseParam(productDetails: details);
//     await _iap.buyNonConsumable(purchaseParam: param);
//   }
//
//   Future<void> restore() async {
//     await _iap.restorePurchases();
//   }
//
//   Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
//     for (final p in purchases) {
//       switch (p.status) {
//         case PurchaseStatus.pending:
//           break;
//         case PurchaseStatus.error:
//           debugPrint('Purchase error: ${p.error}');
//           break;
//         case PurchaseStatus.purchased:
//         case PurchaseStatus.restored:
//           final ok = await _verifyPurchase(p);
//           if (ok) {
//             await _grantEntitlement();
//           }
//           if (p.pendingCompletePurchase) {
//             await _iap.completePurchase(p);
//           }
//           break;
//         case PurchaseStatus.canceled:
//           break;
//       }
//     }
//   }
//
//   Future<bool> _verifyPurchase(PurchaseDetails p) async {
//     // MVP: ローカル検証（本来はサーバー検証）
//     return p.productID == _kProductIdPro;
//   }
//
//   Future<void> _grantEntitlement() async {
//     _isPro = true;
//     notifyListeners();
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(_kEntitlementKey, true);
//   }
//
//   Future<void> _loadEntitlementFromLocal() async {
//     final prefs = await SharedPreferences.getInstance();
//     _isPro = prefs.getBool(_kEntitlementKey) ?? false;
//     notifyListeners();
//   }
// }

// lib/core/purchase/purchase_service.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService with ChangeNotifier {
  static final PurchaseService instance = PurchaseService._internal();
  PurchaseService._internal();
  factory PurchaseService() => instance;

  static const String _kProductIdPro = 'pro_yearly';

  final InAppPurchase _iap = InAppPurchase.instance;
  // final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'asia-northeast1',
  );
  final Set<String> _productIds = {_kProductIdPro};

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;

  bool _isPro = false;
  bool get isPro => _isPro;

  ProductDetails? _proDetails;
  ProductDetails? get proDetails => _proDetails;

  /// 起動時初期化：
  /// 1) ストア接続可否確認
  /// 2) 商品情報取得
  /// 3) サーバーキャッシュから現在のPro状態取得（信頼できる唯一の判定）
  /// 4) 購入ストリーム購読開始
  Future<void> init() async {
    _available = await _iap.isAvailable();

    if (!_available && kDebugMode) {
      // ローカル開発時：ダミー商品を設定
      _proDetails = ProductDetails(
        id: _kProductIdPro,
        title: 'Pro Yearly (Debug)',
        description: 'ローカル開発用ダミー商品',
        price: '¥0',
        rawPrice: 0.0,
        currencyCode: 'JPY',
      );
      notifyListeners();
      return;
    }

    if (_available) {
      final response = await _iap.queryProductDetails(_productIds);
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

    // ✅ サーバーキャッシュ（Firestore）から現在の権利を取得
    await _refreshIsProFromServer();
  }

  Future<void> disposeService() async {
    await _sub?.cancel();
  }

  /// 購入開始（非消費型／買い切り）
  Future<void> buyPro() async {
    final details = _proDetails;
    if (!_available || details == null) {
      throw Exception('ストアに接続できないか商品が見つかりません');
    }
    final param = PurchaseParam(productDetails: details);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// 購入復元（iOS中心の動作。AndroidはqueryPurchasesで自動復元されることも）
  Future<void> restore() async {
    await _iap.restorePurchases();
    // 念のため：復元後にサーバーを強制リフレッシュ（購買履歴を再検証してキャッシュ更新）
    await _forceRefreshEntitlementsOnServer();
    await _refreshIsProFromServer();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // ✅ 端末のレシート/トークンをサーバーへ送って検証＆キャッシュ更新
          final ok = await _submitReceiptToServer(p);
          if (ok) {
            await _refreshIsProFromServer(); // サーバーの最新キャッシュを反映
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
      }
    }
  }

  /// レシート/トークンを Cloud Functions に送って検証・反映
  Future<bool> _submitReceiptToServer(PurchaseDetails p) async {
    try {
      final callable = _functions.httpsCallable('entitlements_submitReceipt');
      final resp = await callable.call(<String, dynamic>{
        'productId': p.productID,
        // iOS: base64 receipt, Android: purchaseToken（serverVerificationDataに入る）
        'verificationData': p.verificationData.serverVerificationData,
        'source': _platformSource(),
        'purchaseId': p.purchaseID, // 任意
      });
      final data = Map<String, dynamic>.from(resp.data as Map);
      // 返却例: { verified: true, isPro: true, plan: "lifetime"|"sub" }
      return (data['verified'] as bool?) ?? false;
    } catch (e) {
      debugPrint('submitReceipt error: $e');
      return false;
    }
  }

  /// サーバー側のentitlementsキャッシュを取得してisPro反映
  Future<void> _refreshIsProFromServer() async {
    try {
      final callable = _functions.httpsCallable('entitlements_getApp');
      final resp = await callable.call(<String, dynamic>{});
      final data = Map<String, dynamic>.from(resp.data as Map);
      final serverIsPro = (data['isPro'] as bool?) ?? false;
      if (_isPro != serverIsPro) {
        _isPro = serverIsPro;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('entitlements_getApp error: $e');
      // サーバーが落ちている場合などは前回値を温存（オフライン耐性）
    }
  }

  /// 強制的にストア再照会→サーバーキャッシュ更新（購入直後・復元後などに使用）
  Future<void> _forceRefreshEntitlementsOnServer() async {
    try {
      final callable = _functions.httpsCallable('entitlements_refreshApp');
      await callable.call(<String, dynamic>{});
    } catch (e) {
      debugPrint('entitlements_refreshApp error: $e');
    }
  }

  String _platformSource() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'appstore';
      case TargetPlatform.android:
        return 'play';
      default:
        return 'unknown';
    }
  }
}
