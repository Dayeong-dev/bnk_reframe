import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';

class FortuneAuthService {
  FortuneAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 내부: 지수 백오프 대기 (0, 400ms, 800ms, 1600ms ± 지터)
  static Future<void> _backoff(int attempt) async {
    if (attempt <= 0) return;
    final base = 400 * pow(2, attempt - 1); // ms
    final jitter = Random().nextInt(120); // 0~119ms
    final delayMs = base.toInt() + jitter;
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// 내부: 사용자 객체가 준비될 때까지 잠깐 기다림 (최대 2초)
  static Future<User?> _waitForUserReady(
      {Duration timeout = const Duration(seconds: 2)}) async {
    final current = _auth.currentUser;
    if (current != null) return current;

    try {
      return await _auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(timeout);
    } catch (_) {
      return _auth.currentUser; // 마지막으로 한 번 더 확인
    }
  }

  /// 어디서든 호출하면 익명 로그인 보장 후 UID 반환.
  /// 네트워크 일시 오류 대비 4회(초기 + 3회 재시도) 시도.
  static Future<String?> ensureSignedIn() async {
    // 이미 로그인되어 있으면 그대로 UID
    final u0 = _auth.currentUser;
    if (u0 != null) return u0.uid;

    Exception? lastError;

    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await _backoff(attempt);
      }
      try {
        // 다른 곳에서 이미 로그인됐을 수도 있으니 먼저 한 번 더 확인
        final cur = _auth.currentUser;
        if (cur != null) return cur.uid;

        await _auth.signInAnonymously();

        final ready = await _waitForUserReady();
        if (ready != null) return ready.uid;

        // 드물게 user가 null이면 다음 루프 재시도
      } catch (e) {
        // 마지막 에러 저장만 하고 재시도
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    // 여기까지 왔으면 실패이지만, 호출자는 null 처리하도록 둠
    // (UI단에서는 테스트 진행은 계속 가능하도록 best-effort 처리)
    if (lastError != null) {
      // 디버그 로그 정도만 남겨두면 충분
      // debugPrint('ensureSignedIn failed: $lastError');
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
    try {
      return await user?.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
  }

  /// 테스트/디버그용
  static Future<void> signOutForTest() async {
    await _auth.signOut();
  }
}
