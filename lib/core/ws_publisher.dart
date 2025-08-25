// lib/event/core/ws_publisher.dart
import 'dart:convert';
import 'package:web_socket_channel/io.dart' as ws_io;
import '../env/app_endpoints.dart';

class WsPublisher {
  static ws_io.IOWebSocketChannel? _ch;

  static Future<void> _ensure() async {
    if (_ch != null) return;
    _ch = ws_io.IOWebSocketChannel.connect(AppEndpoints.wsBase);

    // 끊기면 다음 publish에서 자동 재연결되도록 리셋
    _ch!.stream.listen(
          (_) {}, // 서버의 ack 응답을 굳이 처리할 필요 없으면 무시
      onError: (_) => _ch = null,
      onDone: () => _ch = null,
      cancelOnError: true,
    );
  }

  /// 전역 브로드캐스트 (발급자 제외하려면 excludeSelf=true + issuer 전달)
  static Future<void> publish(
      String topic,
      Map<String, dynamic> data, {
        bool excludeSelf = false,
        String? issuer,
      }) async {
    await _ensure();

    final msg = {
      "op": "publish",
      "token": AppEndpoints.wsPublishToken, // 🔐 서버의 checkSecret과 동일해야 함
      "topic": topic,
      "excludeSelf": excludeSelf,
      if (issuer != null && issuer.isNotEmpty) "issuer": issuer, // 서버가 제외 판단 시 사용
      "data": {
        ...data,
        if (issuer != null && issuer.isNotEmpty) "issuer": issuer, // 수신측에서도 참고 가능
      },
    };

    _ch!.sink.add(jsonEncode(msg));
  }

  static Future<void> close() async {
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }
}
