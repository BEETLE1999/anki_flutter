// lib/core/widgets/bullet_list.dart

import 'package:flutter/material.dart';

/// 箇条書きリストウィジェット（・や1.などに対応）
class BulletList extends StatelessWidget {
  const BulletList({
    super.key,
    required this.items,
    this.numbered = false,
    this.spacing = 4,
  });

  /// 表示する項目
  final List<String> items;
  /// true なら 1. 2. 3. のように数字を付ける
  /// false なら ・ のように点で表示する
  final bool numbered;
  /// 各項目間の縦スペース
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(numbered ? '${i + 1}.' : '・'),
              const SizedBox(width: 6),
              Expanded(child: Text(items[i])),
            ],
          ),
        );
      }),
    );
  }
}
