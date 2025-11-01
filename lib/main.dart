import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/purchase/purchase_service.dart';

import 'core/theme/app_theme.dart';
import 'data/local/hive_init.dart';
import 'features/decks/deck_list_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initHive();
  // 課金サービス初期化
  await PurchaseService.instance.init();
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
