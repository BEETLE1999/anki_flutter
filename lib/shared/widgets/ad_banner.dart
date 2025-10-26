// lib/core/widgets/ad_banner.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// どこでも使えるフッターバナー。中身は child で差し替え可能。
class AdBannerBar extends StatelessWidget {
  const AdBannerBar({
    super.key,
    required this.child,
    this.height = kAdBannerHeight,
    this.onTap,
    this.showTopBorder = true,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final Widget child;
  final double height;
  final VoidCallback? onTap;
  final bool showTopBorder;
  final Color? backgroundColor;
  final EdgeInsets padding;

  static const double kAdBannerHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: backgroundColor ?? scheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              border: showTopBorder
                  ? Border(top: BorderSide(color: AppColors.border, width: 1))
                  : null,
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 文言入りの“仮広告”プリセット。
class AdBannerPlaceholder extends StatelessWidget {
  const AdBannerPlaceholder({
    super.key,
    this.text = '（仮）スポンサー広告バナー：ここに入稿画像やテキストが入ります。',
    this.onTap,
    this.onClose, // TODO きっと不要
    this.height = AdBannerBar.kAdBannerHeight,
    this.showTopBorder = true,
  });

  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final double height;
  final bool showTopBorder;


  @override
  Widget build(BuildContext context) {
    return AdBannerBar(
      showTopBorder: showTopBorder,
      height: height,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.ad_units),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          // IconButton(
          //   tooltip: '閉じる',
          //   onPressed: onClose,
          //   icon: const Icon(Icons.close),
          // ),
        ],
      ),
    );
  }
}
