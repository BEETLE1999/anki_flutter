import 'package:flutter/material.dart';

class AppColors {
  // 背景色（薄いアイボリー）→ 神道的には「生成り」
  static const Color background = Color(0xFFF0EFE2);
  // ほぼ白（淡雪色）
  static const Color appWhite = Color(0xFFFAFAF7);
  // メインテキスト色（落ち着いた墨色）
  static const Color textPrimary = Color(0xFF2A2A2A);
  // サブテキスト色（薄鼠色っぽいグレー）
  static const Color textSecondary = Color(0xFF8A897F);
  // ボーダー・線（鳩羽鼠（はとばねず））
  static const Color border = Color(0xFFBFBDA8);
  // 和紙のような灰白色
  static const Color washiGray = Color(0xFFD6D4C2);
  // ナビゲーション・ホバー用のハイライト（生成りの変化色）
  static const Color navHover = Color(0xFFE7E5D8);
  // 主の神色（神前の深緑・神木を連想）
  static const Color sacredGreen = Color(0xFF4C6A55);
  // 空や清水を連想する薄青（神聖な清浄感）
  static const Color sacredBlue = Color(0xFF8FA8B7);
  // 神社の厳かさ・巫女装束の赤などを意識
  static const Color shrineRed = Color(0xFFB03B3B);
  // ワーニング（和の橙系：黄朽葉色）
  static const Color warning = Color(0xFFD9A066);
  // エラー（神道でも使われる朱・緋系）
  static const Color error = shrineRed;
}
