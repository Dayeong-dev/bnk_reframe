// lib/utils/recent_my_review.dart
import 'dart:collection';

class _Key {
  final int productId;
  final int rating;
  final String snippet; // 서버가 보내는 것과 최대한 유사하게

  _Key(this.productId, this.rating, this.snippet);

  @override
  bool operator ==(Object other) =>
      other is _Key &&
          other.productId == productId &&
          other.rating == rating &&
          other.snippet == snippet;

  @override
  int get hashCode => Object.hash(productId, rating, snippet);
}

/// 내가 방금 올린 리뷰를 잠깐 기억해두었다가,
/// 동일 스니펫/별점의 WS 알림은 무시하게 해주는 간단 버퍼.
class RecentMyReviewBuffer {
  static final RecentMyReviewBuffer I = RecentMyReviewBuffer._();
  RecentMyReviewBuffer._();

  // 저장: key -> expiredAt
  final _store = HashMap<_Key, DateTime>();

  /// 리뷰 제출 직전에 호출
  void markSubmitted({
    required int productId,
    required String contentRaw,
    required int rating,
    Duration ttl = const Duration(seconds: 10),
  }) {
    final snippet = _makeSnippet(contentRaw);
    final key = _Key(productId, rating, snippet);
    _store[key] = DateTime.now().add(ttl);
    _gc();
  }

  /// WS 알림 수신 시, 내 것 같으면 true (=> 배너 스킵)
  bool shouldSuppress({
    required int productId,
    required String snippetFromServer,
    required int rating,
  }) {
    _gc();
    final key = _Key(productId, rating, snippetFromServer);
    if (_store.containsKey(key)) return true;

    // 보조: ellipsis 차이 등 허용
    for (final k in _store.keys) {
      if (k.productId == productId &&
          k.rating == rating &&
          (k.snippet == snippetFromServer ||
              k.snippet.startsWith(snippetFromServer) ||
              snippetFromServer.startsWith(k.snippet))) {
        return true;
      }
    }
    return false;
  }

  // 서버와 비슷한 규칙으로 스니펫 생성(공백 축약 + 24자 + …)
  String _makeSnippet(String s) {
    var t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length > 24) t = t.substring(0, 24) + '…';
    return t;
  }

  void _gc() {
    final now = DateTime.now();
    _store.removeWhere((_, exp) => exp.isBefore(now));
  }
}
