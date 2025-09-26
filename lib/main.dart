import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/adapters.dart';
import 'data/local/entities/deck_entity.dart';
import 'data/local/entities/flashcard_entity.dart';
import 'data/local/hive_init.dart';
import 'features/decks/deck_list_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initHive();

  runApp(const AnkiApp());
}

class AnkiApp extends StatelessWidget {
  const AnkiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anki',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF137D5D),
      ),
      home: const DeckListPage(),
    );
  }
}
