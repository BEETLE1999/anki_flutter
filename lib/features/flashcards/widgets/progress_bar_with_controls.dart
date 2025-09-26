// lib/features/flashcards/widgets/progress_bar_with_controls.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ProgressBarWithControls extends StatelessWidget {
  const ProgressBarWithControls({
    super.key,
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onChanged,
    this.topPadding = 16,
    this.bottomPadding = 20,
  });

  final int index;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onChanged; // ← 追加: スライダーで移動したときのコールバック
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final clampedIndex = total == 0 ? 0 : index.clamp(0, total - 1);

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 32),
                onPressed: onPrev,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: clampedIndex.toDouble(),
                    min: 0,
                    max: (total == 0 ? 1 : total - 1).toDouble(),
                    divisions: null,
                    label: '${clampedIndex + 1} / $total',
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: AppColors.washiGray,
                    onChanged: (value) {
                      onChanged(value.round());
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 32),
                onPressed: onNext,
              ),
            ],
          ),
          Text(
            '${clampedIndex + 1} / $total',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1),
          ),
        ],
      ),
    );
  }
}
