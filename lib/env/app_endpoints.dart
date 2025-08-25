import '../constants/api_constants.dart';

class AppEndpoints {
  // Spring REST API (스키마/호스트/포트 환경에 맞게 수정)
  static const apiBase = apiBaseUrl; // ex) https://api.mybank.com
  static const apiPrefix = '$apiBase/api';

  // Netty WebSocket
  // 운영은 wss:// 권장. ex) wss://ws.mybank.com/ws
  static const wsBase = 'ws://$apiUrl:8081/ws';

  // 🔵 전역 쿠폰 이벤트 토픽
  static const wsTopicCoupons = 'events.coupons';

  static const wsPublishToken = 'MY_SECRET_123';
}
