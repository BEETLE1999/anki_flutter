// lib/core/entitlements/entitlements_service.dart

import 'package:cloud_functions/cloud_functions.dart';

import 'model/entitlements.dart';

class EntitlementsService {
  EntitlementsService._();
  static final instance = EntitlementsService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-northeast1',
  );

  Entitlements? _cache;

  Future<Entitlements> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final callable = _functions.httpsCallable('entitlements_getApp');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);

    final ent = Entitlements.fromMap(data);
    _cache = ent;
    return ent;
  }
}
