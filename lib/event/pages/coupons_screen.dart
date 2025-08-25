import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import 'coupons_page.dart';
import 'coupon_detail_page.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  String? _uid;

  String? _lastNotifiedCouponId;
  bool _couponStreamInitialized = false;

  @override
  void initState() {
    super.initState();
    _uid = FortuneAuthService.getCurrentUid();
    // ✅ 초대한 사람(=현재 로그인 사용자)의 미정산 방문 정산 시도
    _applyInviteRewards();
  }

  Future<void> _applyInviteRewards() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // 규칙상 inviter 본인만 자신의 invites 하위를 list/update 가능
      final n =
          await FortuneFirestoreService.claimPendingInvitesAndIssueRewards(
              inviterUid: uid, batchSize: 20);
      if (n > 0) {
        debugPrint('✅ invite rewards claimed: $n for inviter=$uid');
        if (!mounted) return;
        // 살짝 피드백(선택)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 방문 $n건이 정산되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ invite reward apply failed (inviter view): $e');
      // 권한 오류가 나면, 실제로 inviter가 아닌 계정일 가능성. UI는 계속 노출.
    }
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
      appBar: AppBar(title: const Text('내 쿠폰/스탬프')),
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

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FortuneFirestoreService.streamLatestCoupon(uid),
            builder: (context, couponSnap) {
              if (couponSnap.hasData) {
                final docs = couponSnap.data!.docs;
                if (docs.isNotEmpty) {
                  final latest = docs.first;
                  if (_couponStreamInitialized &&
                      latest.id != _lastNotifiedCouponId) {
                    _notifyNewCoupon(latest.id, latest.data());
                  }
                  _lastNotifiedCouponId = latest.id;
                  _couponStreamInitialized = true;
                } else {
                  _lastNotifiedCouponId = null;
                  _couponStreamInitialized = true;
                }
              }

              // ✅ 내용 전용 CouponsPage 사용 (AppBar 없음)
              return CouponsPage(
                stampCount: stampCount,
                onFull: () {
                  debugPrint('스탬프 만땅!');
                },
              );
            },
          );
        },
      ),
    );
  }

  void _notifyNewCoupon(String couponId, Map<String, dynamic> coupon) {
    final title = (coupon['title'] ?? '새 쿠폰이 도착했어요!').toString();
    final code = (coupon['code'] ?? '').toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(code.isEmpty ? title : '$title 코드: $code'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '보기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CouponDetailPage(couponId: couponId)),
              );
            },
          ),
        ),
      );
    });
  }
}
