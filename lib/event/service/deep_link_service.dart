import 'dart:async';
import 'package:app_links/app_links.dart';

typedef OnInvite = Future<void> Function(Uri uri);

class DeepLinkService {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  // 동일 URI 중복 처리 방지
  String? _lastHandled;

  // ====== 환경 상수 ======
  // 커스텀 스킴 (AndroidManifest의 <data android:scheme / android:host>와 동일)
  static const String _customScheme = 'bnk-app-push';
  static const String _customHost   = 'bnk_reframe';

  // HTTPS 호스트(유니버설/앱 링크용). 필요 시 커스텀 도메인도 여기에 추가.
  static const Set<String> _httpsHosts = {
    'bnk-app-push.web.app',
    'bnk-app-push.firebaseapp.com',
    // TODO: 구(旧) 프로젝트 호스트를 임시로 허용하려면 아래 주석 해제
    // 'abc123-2580c.web.app',
  };

  // 허용 경로: /fortune/*, /open-app3.html
  static bool _isAllowedPath(Uri uri) {
    if (uri.path == '/open-app3.html') return true;
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'fortune') {
      return true;
    }
    return false;
  }

  // 초대 파라미터 존재 여부
  static bool _hasInviteParam(Uri uri) {
    final q = uri.queryParameters;
    return q.containsKey('inviteCode') || q.containsKey('inviter') || q.containsKey('code');
  }

  // 이 링크가 우리 앱용인가?
  static bool _isOurLink(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host   = uri.host.toLowerCase();

    final isCustom =
    (scheme == _customScheme && host == _customHost);

    final isHttps =
    (scheme == 'https' && _httpsHosts.contains(host) && (_hasInviteParam(uri) || _isAllowedPath(uri)));

    return isCustom || isHttps;
  }

  Future<void> init(OnInvite onInvite) async {
    _appLinks = AppLinks();

    // (A) 앱이 링크로 시작된 경우
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _handle(initial, onInvite, source: 'initial');
    }

    // (B) 실행 중 들어오는 링크
    _sub = _appLinks.uriLinkStream.listen(
          (uri) => _handle(uri, onInvite, source: 'stream'),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _handle(Uri uri, OnInvite onInvite, {String source = ''}) async {
    if (!_isOurLink(uri)) return;

    // 같은 URI 두 번 들어오는 케이스 차단
    final key = uri.toString();
    if (_lastHandled == key) return;
    _lastHandled = key;

    await onInvite(uri);
  }

  void dispose() => _sub?.cancel();
}