// lib/core/ws_subscriber.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart' as ws_io;

class WsSubscriber {
  final String baseUrl;               // 예: ws://host/ws
  final List<String> topics;          // 예: ['coupon.issued']
  final String? uid;                  // 예: 내 UID
  final Duration pingInterval;        // 핑 주기
  final Duration reconnectMinDelay;   // 재연결 최소
  final Duration reconnectMaxDelay;   // 재연결 최대

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  bool _manuallyClosed = false;
  int _retry = 0;
  Timer? _pingTimer;

  Stream<Map<String, dynamic>> get messages => _ctrl.stream;

  WsSubscriber({
    required this.baseUrl,
    required this.topics,
    this.uid,
    this.pingInterval = const Duration(seconds: 20),
    this.reconnectMinDelay = const Duration(milliseconds: 800),
    this.reconnectMaxDelay = const Duration(seconds: 7),
  });

  Future<void> connect() async {
    _manuallyClosed = false;
    await _open();
  }

  Future<void> dispose() async {
    _manuallyClosed = true;
    _pingTimer?.cancel();
    await _sub?.cancel();
    try { await _ch?.sink.close(); } catch (_) {}
    await _ctrl.close();
  }

  Future<void> _open() async {
    final qp = <String, dynamic>{};
    if (uid != null) qp['uid'] = uid!;
    // 서버 자동 구독 지원: 여러 topic 쿼리 허용한다면 다음처럼 반복 추가
    for (final t in topics) {
      qp['topic'] = t; // 서버가 중복 key 허용 시 OK, 아니면 하나만 자동구독됨
    }
    final uri = Uri.parse(baseUrl).replace(queryParameters: qp);

    try {
      _ch = ws_io.IOWebSocketChannel.connect(uri.toString());

      // 안전빵: 수동 구독 프레임
      _ch!.sink.add(jsonEncode({"op": "subscribe", "topics": topics}));

      // 주기 핑
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(pingInterval, (_) {
        try { _ch?.sink.add(jsonEncode({"op": "ping"})); } catch (_) {}
      });

      _sub = _ch!.stream.listen((raw) {
        _retry = 0;
        final text = raw is String ? raw : raw.toString();
        try {
          final msg = jsonDecode(text);
          if (msg is Map<String, dynamic>) _ctrl.add(msg);
        } catch (_) {}
      }, onError: (_) => _reconnect(), onDone: _reconnect);
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    _pingTimer?.cancel();
    if (_manuallyClosed) return;
    _retry++;
    final delayMs = (_retry * 600).clamp(
      reconnectMinDelay.inMilliseconds,
      reconnectMaxDelay.inMilliseconds,
    );
    Future.delayed(Duration(milliseconds: delayMs), _open);
  }
}
