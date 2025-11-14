import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/auth/auth_service.dart';
import 'core/purchase/purchase_service.dart';

import 'core/theme/app_theme.dart';
import 'data/local/hive_init.dart';
import 'features/decks/deck_list_page.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate();
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider() // 本番：Play Integrity
        : const AndroidDebugProvider(), // 開発：Debug Provider
    providerApple: kReleaseMode
        ? const AppleAppAttestProvider() // 本番：App Attest
        : const AppleDebugProvider(), // 開発：Debug Provider
  );
  await initHive();
  // 匿名サインイン（UIDを必ず確保）
  final auth = AuthService();
  await auth.signInAnonymouslyIfNeeded();
  // 課金サービス初期化
  await PurchaseService.instance.init();

  // TODO
  debugFirebaseTargets();

  runApp(const AnkiApp());
}

class AnkiApp extends StatelessWidget {
  const AnkiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anki',
      theme: AppTheme.light,
      home: const DeckListPage(),
    );
  }
}

// TODO
Future<void> debugFirebaseTargets() async {
  final app = Firebase.app();
  final o = app.options;
  print('[FB] projectId=${o.projectId}, appId=${o.appId}');

  final fDefault = FirebaseFunctions.instance; // us-central1
  final fTokyo = FirebaseFunctions.instanceFor(
    app: app,
    region: 'asia-northeast1',
  );
  print('[FB] default (us-central1) => $fDefault');
  print('[FB] tokyo   (asia-northeast1) => $fTokyo');

  // 実呼び出し（東京経由）
  try {
    final r = await fTokyo.httpsCallable('entitlements_getApp').call({});
    print('[FB] call via tokyo OK: ${r.data}');
  } on FirebaseFunctionsException catch (e) {
    print('[FB] call via tokyo ERROR: ${e.code} ${e.message}');
  }
}
