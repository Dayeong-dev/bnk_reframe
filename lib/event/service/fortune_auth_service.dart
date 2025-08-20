import 'package:firebase_auth/firebase_auth.dart';

class FortuneAuthService {
  FortuneAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// (신규) 어디서든 호출하면 익명 로그인 보장 후 UID 반환
  static Future<String?> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    return _auth.currentUser?.uid;
  }

  /// (호환) 기존 코드 유지용: 내부적으로 ensureSignedIn() 호출
  static Future<void> signInAnonymously() async {
    await ensureSignedIn();
  }

  static String? getCurrentUid() => _auth.currentUser?.uid;

  static bool get isSignedIn => _auth.currentUser != null;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Stream<String?> uidStream() =>
      _auth.authStateChanges().map((u) => u?.uid);

  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    return user?.getIdToken(forceRefresh);
  }

  /// 테스트/디버그용
  static Future<void> signOutForTest() async {
    await _auth.signOut();
  }
}
