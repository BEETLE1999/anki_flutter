// lib/features/flashcards/widgets/swipe_bg.dart
import 'package:flutter/material.dart';

class SwipeBg extends StatelessWidget {
  const SwipeBg({
    super.key,
    required this.icon,
    required this.alignLeft,
    required this.label,
  });

  final IconData icon;
  final bool alignLeft;
  final String label;

  @override
  Widget build(BuildContext context) {
    final align = alignLeft ? Alignment.centerLeft : Alignment.centerRight;
    final pad = alignLeft
        ? const EdgeInsets.only(left: 20)
        : const EdgeInsets.only(right: 20);

    return Container(
      alignment: align,
      padding: pad,
      // color: alignLeft
      //     ? Colors.green.withOpacity(0.15)
      //     : Colors.orange.withOpacity(0.15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignLeft) Text(label),
          const SizedBox(width: 8),
          Icon(icon,size: 48,),
          if (alignLeft) ...[const SizedBox(width: 8), Text(label)],
        ],
      ),
    );
  }
}
