// lib/event/config/share_links.dart
class ShareLinks {
  // 🔧 프로젝트 맞춰서 한 번만 세팅
  static const String hostingHost = 'bnk-app-push.web.app'; // 배포 호스트
  static const String openPagePath = '/open-app3.html';

  // Android 패키지명(= applicationId). 실제 값으로!
  static const String androidPackage = 'com.example.reframe';

  // 스토어 링크 (옵션)
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';
  static const String appStoreUrl =
      'https://apps.apple.com/app/id000000000'; // iOS 쓰면 실제 id로 교체

  /// 카톡 등 “웹 → 앱 전환” 공유용 링크
  static String shareUrl({required String inviteCode, String src = 'result'}) {
    final qp = Uri(queryParameters: {
      'inviteCode': inviteCode,
      'src': src,
    }).query;
    return 'https://$hostingHost$openPagePath?$qp';
  }
}
