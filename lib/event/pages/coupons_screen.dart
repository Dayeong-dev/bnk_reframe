// lib/event/pages/coupons_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import 'coupons_page.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  String? _uid;

  // 새 쿠폰 감지용
  String? _lastNotifiedCouponId;
  bool _couponStreamInitialized = false;

  @override
  void initState() {
    super.initState();
    _uid = FortuneAuthService.getCurrentUid();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내 쿠폰 / 스탬프')),
      body: StreamBuilder<int>(
        stream: FortuneFirestoreService.streamStampCount(uid),
        builder: (context, stampSnap) {
          if (stampSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (stampSnap.hasError) {
            return Center(child: Text('오류: ${stampSnap.error}'));
          }
          if (!stampSnap.hasData) {
            return const SizedBox.shrink();
          }
          final stampCount = stampSnap.data!;

          // 최신 쿠폰 1건 구독 (새로 생기면 스낵바 알림)
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FortuneFirestoreService.streamLatestCoupon(uid),
            builder: (context, couponSnap) {
              if (couponSnap.hasData) {
                final docs = couponSnap.data!.docs;
                if (docs.isNotEmpty) {
                  final latest = docs.first;
                  // 초기 수신은 저장만 하고 알림 스킵
                  if (_couponStreamInitialized &&
                      latest.id != _lastNotifiedCouponId) {
                    _notifyNewCoupon(latest.data());
                  }
                  _lastNotifiedCouponId = latest.id;
                  _couponStreamInitialized = true;
                } else {
                  // 비어있다가 이후 생성되면 알림
                  _lastNotifiedCouponId = null;
                  _couponStreamInitialized = true;
                }
              }

              return CouponsPage(
                stampCount: stampCount,
                onFull: () {
                  // 표시만 (발급/초기화는 서버 트랜잭션에서 이미 처리됨)
                  debugPrint('스탬프 만땅!');
                },
              );
            },
          );
        },
      ),
    );
  }

  void _notifyNewCoupon(Map<String, dynamic> coupon) {
    final title = (coupon['title'] ?? '새 쿠폰이 도착했어요!').toString();
    final code = coupon['code'] != null ? ' 코드: ${coupon['code']}' : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title$code'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '보기',
            onPressed: () {
              // TODO: 쿠폰함 페이지로 이동 or 바텀시트 열기
              // Navigator.pushNamed(context, '/my-coupons');
            },
          ),
        ),
      );
    });
  }
}
