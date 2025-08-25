// lib/event/core/live_coupon_announcer.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../service/fortune_auth_service.dart';
import '../../env/app_endpoints.dart';
import '../../core/ws_subscriber.dart';
import '../../../main.dart' show navigatorKey;

/// 쿠폰 실시간 알림 (상단 흰색 칩 + 종 아이콘 + 텍스트)
class LiveCouponAnnouncer {
  LiveCouponAnnouncer._();
  static final LiveCouponAnnouncer I = LiveCouponAnnouncer._();

  WsSubscriber? _ws;
  StreamSubscription<Map<String, dynamic>>? _sub;

  OverlayEntry? _entry;
  Timer? _hideTimer;

  // 알림 문구 갱신용
  final ValueNotifier<String> _message = ValueNotifier<String>('');

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FortuneAuthService.getCurrentUid();
      _ws = WsSubscriber(
        baseUrl: AppEndpoints.wsBase,
        topics: [AppEndpoints.wsTopicCoupons],
        uid: uid,
      );
      _ws!.connect();
      _sub = _ws!.messages.listen(_onWsMessage, onError: (_) {}, onDone: () {});
    });
  }

  void dispose() {
    _sub?.cancel();
    _ws?.dispose();
    _sub = null;
    _ws = null;
    _removeOverlay(immediate: true);
    _started = false;
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if ((msg['type'] ?? '') != 'coupon_issued') return;

    // 자기 자신 이벤트면 무시
    final issuer = (msg['issuer'] ?? '').toString();
    final me = FortuneAuthService.getCurrentUid();
    if (issuer.isNotEmpty && issuer == me) return;

    final masked = (msg['maskedName'] ?? '오**').toString();
    final hm = _nowHMKorean(); // "14시 30분"

    // 시/분을 앞으로, 점(·) 없이 공백만
    final text = '$hm $masked님 기프티콘 획득';
    _show(text);
  }

  String _nowHMKorean() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    // 시간은 앞에 0 없이, 분만 2자리
    return '${n.hour}시 ${two(n.minute)}분';
  }

  void _show(String text) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(text));
      return;
    }

    _message.value = text;

    if (!(_entry?.mounted ?? false)) {
      _entry = OverlayEntry(
        builder: (context) {
          final safeTop = MediaQuery.of(context).padding.top;
          final maxW =
          math.min(MediaQuery.of(context).size.width - 24, 560.0);

          return IgnorePointer(
            ignoring: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: safeTop + 10),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: maxW),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_active, // 사용자가 지정한 아이콘 유지
                                size: 18,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ValueListenableBuilder<String>(
                                  valueListenable: _message,
                                  builder: (_, value, __) => Text(
                                    value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
      overlayState.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), _removeOverlay);
  }

  void _removeOverlay({bool immediate = false}) {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (!(_entry?.mounted ?? false)) {
      _entry = null;
      return;
    }
    try {
      _entry!.remove();
    } catch (_) {}
    _entry = null;
  }
}
