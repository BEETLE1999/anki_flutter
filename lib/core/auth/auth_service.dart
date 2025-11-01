// lib/core/auth/auth_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// v7: initialize をアプリ起動時に一度だけ実行
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      await GoogleSignIn.instance.initialize();
      _initialized = true;
      // サイレント（軽量）認証を試す（失敗しても問題なし）
      unawaited(GoogleSignIn.instance.attemptLightweightAuthentication());
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      rethrow;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Google でログイン → FirebaseAuth へサインイン
  Future<UserCredential> signInWithGoogle() async {
    await _ensureInitialized();

    // 1) サインインUI（v7: authenticate）
    final account = await GoogleSignIn.instance.authenticate();

    // 2) 認証トークン（idToken）を取得
    final auth = account.authentication; // v7: idTokenのみを保持
    final String? idToken = auth.idToken;
    if (idToken == null) {
      throw StateError('idToken を取得できませんでした（serverClientId を確認）');
    }

    // 3) 認可トークン（accessToken）を取得
    //    Firebase Auth の GoogleAuthProvider.credential は accessToken も渡すのが確実
    //    必須スコープは "openid", "email", "profile"
    const scopes = <String>['openid', 'email', 'profile'];
    final authorization = await account.authorizationClient
        .authorizationForScopes(scopes); // 既に許可済みなら UI なしで取れる

    final accessToken = authorization?.accessToken;
    if (accessToken == null) {
      // 未許可なら、ユーザー操作で authorizeScopes を呼び出す必要がある
      // （ボタン押下ハンドラ内で実行するのが推奨）
      // ここではフォールバックとして明示的に要求
      final authz = await account.authorizationClient.authorizeScopes(scopes);
      // それでも null なら例外
      if (authz.accessToken.isEmpty) {
        throw StateError('accessToken を取得できませんでした（scopes/セットアップ要確認）');
      }
    }

    // 直近のトークンを再取得（authorizeScopes 後は authorizationForScopes でもOK）
    final token = await account.authorizationClient.authorizationForScopes(
      scopes,
    );

    // 4) Firebase 用の credential 作成
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: token?.accessToken,
    );

    // 5) FirebaseAuth にサインイン
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// （任意）未ログインなら匿名で入れておくとUXが良い
  Future<void> signInAnonymouslyIfNeeded() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }
}
