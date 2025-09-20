// lib/features/flashcards/widgets/flip_card.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 250),
    this.onFlipped,
    this.initialBack = false,
  });

  final Widget front;
  final Widget back;
  final Duration duration;
  final VoidCallback? onFlipped;
  final bool initialBack;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isBack = false;

  @override
  void initState() {
    super.initState();
    _isBack = widget.initialBack;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _isBack ? 1 : 0,
    );
  }

  void flip() {
    setState(() => _isBack = !_isBack);
    if (_isBack) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onFlipped?.call();
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新しいカードに切り替わったら表に戻す
    if (oldWidget.front.key != widget.front.key) {
      _isBack = false;
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          final isFront = angle <= math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D奥行き
              ..rotateY(angle),
            child: isFront
                ? widget.front
                : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: widget.back,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
