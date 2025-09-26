// lib/features/flashcards/widgets/flashcard_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enum.dart';

class FlashcardBottomNav extends StatelessWidget {
  const FlashcardBottomNav({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final CardFilter filter;
  final ValueChanged<CardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: switch (filter) {
        CardFilter.all => 0,
        CardFilter.unread => 1,
        CardFilter.bookmarked => 2,
      },
      onDestinationSelected: (i) {
        onChanged(switch (i) {
          0 => CardFilter.all,
          1 => CardFilter.unread,
          2 => CardFilter.bookmarked,
          _ => CardFilter.all,
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Symbols.note_stack, fontWeight: FontWeight.bold),
          selectedIcon: Icon(Symbols.note_stack, fontWeight: FontWeight.bold),
          label: 'すべて',
        ),
        NavigationDestination(
          icon: Icon(Symbols.check_circle, fontWeight: FontWeight.bold),
          selectedIcon: Icon(Symbols.check_circle, fontWeight: FontWeight.bold),
          label: '未完了',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark, fontWeight: FontWeight.bold),
          selectedIcon: Icon(Icons.bookmark, fontWeight: FontWeight.bold),
          label: 'ブックマーク',
        ),
      ],
    );
  }
}
