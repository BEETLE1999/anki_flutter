import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/constants/app_enum.dart';
import '../../../core/theme/app_colors.dart';
import '../deck.dart';

class DeckTile extends StatelessWidget {
  const DeckTile({super.key, required this.deck, required this.onTap});

  final Deck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${deck.updatedAt.year}/'
        '${deck.updatedAt.month.toString().padLeft(2, '0')}/'
        '${deck.updatedAt.day.toString().padLeft(2, '0')} '
        '${deck.updatedAt.hour.toString().padLeft(2, '0')}:'
        '${deck.updatedAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.title,
                    // "テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳",
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deck.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      deck.description,
                      // "テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳テスト単語帳",
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '作成: $dateStr',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Symbols.note_stack, size: 20),
                      Padding(
                        padding: const EdgeInsets.only(left: 2, right: 12),
                        child: Text('30'),
                      ),
                      Icon(
                        Symbols.check_circle,
                        size: 20,
                        fill: IconFill.filled.value,
                        color: theme.colorScheme.primary,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 2, right: 8),
                        child: Text('45%'),
                      ),
                      Icon(
                        Symbols.bookmark,
                        size: 20,
                        fill: IconFill.filled.value,
                        color: theme.colorScheme.primary,
                      ),
                      Text('30'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 30,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
