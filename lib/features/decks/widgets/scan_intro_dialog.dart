import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/bullet_list.dart';

/// QRインポートの事前説明ダイアログ
class ScanIntroDialog extends StatelessWidget {
  const ScanIntroDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ScanIntroDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const steps = [
      'PCでウェブサイト「単語帳.jp インポートツール」を開く',
      'インポートツールで単語帳データを作成してQRコードを発行',
      '下の「カメラ起動」を押してQRを読み取る',
    ];
    return AlertDialog(
      title: const Text('単語帳インポート'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('カメラを起動して、QRコードによる単語帳インポートを開始します。'),
          SizedBox(height: 12),
          Text('【手順】'),
          const BulletList(items: steps, numbered: true),
          SizedBox(height: 32),
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('単語帳.jp インポートツール URL',style: TextStyle(fontWeight: FontWeight.bold),),
                Text(AppConstants.importSiteUrl),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('カメラ起動'),
        ),
      ],
    );
  }
}
