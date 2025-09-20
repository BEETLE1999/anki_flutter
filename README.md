# anki_flutter

Flutter Anki Project

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.




## 2. 画面（Flutter）
#### 2.1 スプラッシュ/起動
- 生体認証オプション可（既存仕様：`initState` → `Future.microtask` で認証、失敗時は `SystemNavigator.pop()`）

#### 2.2 ログイン
- Google サインイン（初回のみ）
- オフライン時はローカルデータで続行可

#### 2.3 デッキ一覧
- デッキカード表示（タイトル、件数、最終学習日時、進捗バー）
- 並び替え（最近/名前/進捗）、検索、タグフィルタ
- 右上：インポート受信、設定

#### 2.4 学習画面（フラッシュカード）
- 表面表示 → タップ/スワイプで裏面
- アクション：正解・不正解・ブックマーク・スキップ
- 進捗 HUD（本日の学習数、残り、正解率）
- 学習モード：ランダム / 間隔反復（SRS） / 直近ミス優先

#### 2.5 カード編集
- 単語・意味・例文・メモ・タグ・画像URL
- 一括編集（選択→タグ付け/削除）

#### 2.6 進捗/統計
- 期間別正解率、連続日数、デッキ別ヒートマップ（将来）

#### 2.7 設定
- テーマ、フォント、学習モード既定、バックアップ/復元、バイオメトリクスON/OFF

---

## 3. Web（Angular）インポート
#### 3.1 入力
- テキストエリアに Excel からコピペ（TSV/CSV/行ごと）
- 列マッピング（front/back/reading/example/tags）
- デッキ名、既存デッキに追加 or 新規作成

#### 3.2 バリデーション/プレビュー
- レコード件数、重複チェック、空行除去、タグ整形

#### 3.3 送信
- Firestore の一時コレクションへ保存（ユーザーID毎に隔離）
- レコード分割（最大500/バッチ目安）、アップロード完了通知表示

---

## 4. データモデル
#### エンティティ
- User
    - userId, displayName, email, createdAt
- Deck
    - deckId（端末ローカル生成UUID）, title, description, tags[], createdAt, updatedAt, cardCount
- Card
    - cardId（ローカルUUID）, deckId, front, back, reading?, example?, memo?, tags[], createdAt, updatedAt
- StudyProgress（ローカル）
    - cardId, status（new/learning/review/graduated）, ease（SRS用）, interval, dueDate, correctStreak, wrongStreak, lastResult
- Bookmark（ローカル）
    - cardId（ブックマークON/OFF）
- ImportJob（Firestore 一時領域）
    - jobId, userId, deckTitle, rows[{front,back,reading,example,tags[]}] , createdAt, expiresAt

#### ローカル保存
- Hive（軽量・高速、端末オンリー）
- 将来的に SQLite（検索/JOIN/全文検索が必要になったら移行）

---

## 5. 同期/受信フロー
- 1) Angular が `import_jobs/{userId}/{jobId}` に一時保存
- 2) Flutter の「インポート受信」操作で当該ユーザーの job を一覧取得
- 3) 選択→ダウンロードして端末ローカルに Deck/Card を永続化（Hive）
- 4) 完了後、FireStore の `import_jobs/{userId}/{jobId}` を削除（サーバ側データは保持しない仕様）
- 5) 同名デッキがある場合：マージ or 新規作成を選択（初期は新規作成のみでも可）

---

## 6. 学習ロジック（初期仕様）
- モードA：シンプル（ランダム、表→裏→結果）
- モードB：直近ミス優先（wrongStreak>0 を優先出題）
- モードC：SRS（SM2 風）
    - 初見は status=new → learning
    - 正解で ease/interval を更新、dueDate で出題制御
    - 不正解で ease 減少、間隔短縮、直近で再出題
- 既定は A（まず実装容易なモード）

---

## 7. 非機能要件
- オフラインファースト：学習・検索は通信不要
- パフォーマンス：デッキ 1万カード規模でも一覧/検索が実用
- 起動時間：2秒以内（キャッシュ/遅延読込）
- 安定性：学習セッション中はクラッシュ復帰しても直前の位置を復元
- 可観測性：簡易ログ（学習回数、エラー）をローカル収集（将来送信）

---

## 8. セキュリティ/権限
- 認証：Firebase Auth（Google）
- Firestore セキュリティルール（概念）
    - `import_jobs/{userId}/{jobId}` は `request.auth.uid == userId` のみ読み書き可
    - TTL で自動削除（Cloud Scheduler + Function or Firestore TTL）
- 端末データ：ローカル保存（Hive）。OSバックアップ対象はユーザー任意
- 生体認証を任意で学習起動時に要求可

---

## 9. エラーハンドリング
- インポート失敗：行番号・原因（列不足/文字化け/サイズ超過）を UI に表示
- 受信時ネットワーク不通：ローカルにキューして再試行
- 学習時の空デッキ：ガイド（「カードをインポートしてください」）
- 例外共通：トースト + ログ記録（再現性の高いものはダイアログ）

---

## 10. 技術スタック
- モバイル：Flutter（Dart）
    - 状態管理：Riverpod 推奨（軽量・テスト容易）
    - ルーティング：go_router
    - 永続化：Hive（v1）、必要に応じ SQLite へ拡張
- Web：Angular（v17+ 推奨）
    - Standalone コンポーネント、Material 3、Tailwind 併用可
- バックエンド：Firebase
    - Auth（Google）、Firestore（インポート一時領域のみ）
    - Functions（TTL/クリーンアップ任意）
- CI/CD：Flutter build / Angular build、Firebase Hosting（Web）

---

## 11. Firestore 構造（例）
- `import_jobs/{userId}/{jobId}`
    - `deckTitle: string`
    - `rows: [{front, back, reading?, example?, tags?[]}]`
    - `createdAt: serverTimestamp`
    - `expiresAt: serverTimestamp`（TTL）

---

## 12. 進捗指標
- デッキ正解率＝正解数 / 学習数
- 連続日数＝当日学習>0 を連続カウント
- カード難易度＝ease（SRS係数）または wrongStreak

---

## 13. 最低限の v1 スコープ
- Google ログイン
- デッキ一覧/作成/削除
- 学習（ランダム・正解/不正解・ブックマーク）
- Angular からのインポート → 受信 → ローカル保存 → Firestore削除
- 検索/タグフィルタ
- 簡易統計（件数/正解率）
- 生体認証（任意）

---

## 14. 後続アイデア（v1.1+）
- SRS 本格実装（SM2/FSRS）
- 画像/音声付きカード
- クラウドバックアップ（暗号化オプション）
- 共有/エクスポート（CSV/TSV）
- スマホ内ドラッグ&ドロップ並び替え
- カードの埋め込み数式/コード表示
- 学習通知（ローカル通知、毎朝9:00 など）

---

## 15. テスト観点（抜粋）
- インポート整合性（列ズレ、重複、タグ分割）
- Firestore → 端末保存 → Firestore削除の原子性（少なくとも 1 回系）
- 大規模データ（1万件）での検索/ページング
- 生体認証失敗時の動作（既存仕様準拠）
- オフライン時の学習・復帰
- 端末移行（バックアップ/復元）

---

## 16. 開発マイルストン（例）
- M1：デッキ/カードのローカル CRUD、学習（ランダム）
- M2：Angular インポート（プレビュー/送信）、Flutter 受信/保存/削除
- M3：検索/タグ、ブックマーク、簡易統計
- M4：生体認証、エラーハンドリング強化
- M5：SRS β、UX微調整、パフォーマンス最適化
