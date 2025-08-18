class AppEndpoints {
  // Spring REST API (스키마/호스트/포트 환경에 맞게 수정)
  static const apiBase = 'http://192.168.100.135:8090'; // ex) https://api.mybank.com
  static const apiPrefix = '$apiBase/api';

  // Netty WebSocket
  // 운영은 wss:// 권장. ex) wss://ws.mybank.com/ws
  static const wsBase = 'ws://192.168.100.135:8081/ws';
}
