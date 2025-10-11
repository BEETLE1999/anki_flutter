import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

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
    return AlertDialog(
      title: const Text('単語帳インポート'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('カメラを起動して、QRコードによる単語帳インポートを開始します。'),
          SizedBox(height: 12),
          Text(
            '【手順】\n'
            '1. PCでウェブサイト「大人の単語帳　インポートツール」を開く\n'
            '2. 単語帳データを作成してQRコードを発行\n'
            '3. この画面で「カメラ起動」を押してQRを読み取る',
          ),
          SizedBox(height: 32),
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('単語帳インポートツール（ウェブサイト）'),
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
