// lib/pages/my_coupons_page.dart
import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import 'coupon_detail_page.dart';

/// 스타일 토큰
const _brand = Color(0xFF304FFE);
const _border = Color(0xFFE6E9EF);
const _cardBg = Color(0xFFF9FAFB);
const _label = Color(0xFF6B7280);
const _ok = Color(0xFF17B26A);
const _warn = Color(0xFFF63D68);
const _info = Color(0xFF2563EB);

class MyCouponsPage extends StatelessWidget {
  const MyCouponsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('로그인이 필요합니다.'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 쿠폰함'),
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '쿠폰함 공유',
            onPressed: () async {
              await Share.share('내 쿠폰함에서 보유 쿠폰을 확인했어요!');
            },
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FortuneFirestoreService.streamCoupons(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류가 발생했어요: ${snap.error}'));
          }

          final rawDocs = snap.data?.docs ?? [];
          if (rawDocs.isEmpty) {
            return _EmptyState(
              onGoEvent: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이벤트 페이지 라우트를 연결해 주세요.')),
                );
              },
            );
          }

          // 발급일 내림차순
          final docs = [...rawDocs]..sort((a, b) {
              final ai = a.data()['issuedAt'];
              final bi = b.data()['issuedAt'];
              final ad = (ai is Timestamp)
                  ? ai.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
              final bd = (bi is Timestamp)
                  ? bi.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });

          return RefreshIndicator(
            color: _brand,
            onRefresh: () async =>
                Future<void>.delayed(const Duration(milliseconds: 300)),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data();

                final title = (data['title'] ?? '이벤트 쿠폰').toString();
                final code = (data['code'] ?? '').toString();
                final status = (data['status'] ?? 'ISSUED').toString();
                final issuedAt = _fmtTs(data['issuedAt']);
                final redeemedAt = _fmtTs(data['redeemedAt']);

                final state = _CouponState.fromStatus(status);
                final isIssued = state == _CouponState.issued;

                return _CouponCard(
                  title: title,
                  code: code,
                  issuedAt: issuedAt,
                  redeemedAt: redeemedAt,
                  state: state,
                  onTapDetail: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CouponDetailPage(couponId: doc.id),
                      ),
                    );
                  },
                  onTapRedeem: !isIssued
                      ? null
                      : () async {
                          final ok = await showAppConfirmDialog(
                            context: context,
                            icon: Icons.check_circle_outline_rounded,
                            title: '쿠폰 사용하기',
                            message: '이 쿠폰을 사용 처리할까요? 되돌릴 수 없어요.',
                            confirmText: '사용',
                          );
                          if (ok != true) return;

                          await FortuneFirestoreService.redeemCoupon(doc.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('사용 완료 처리했습니다.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// ========== 카드 위젯(통일 레이아웃) ==========
class _CouponCard extends StatelessWidget {
  final String title;
  final String code;
  final String issuedAt;
  final String redeemedAt;
  final _CouponState state;
  final VoidCallback onTapDetail;
  final VoidCallback? onTapRedeem;

  const _CouponCard({
    required this.title,
    required this.code,
    required this.issuedAt,
    required this.redeemedAt,
    required this.state,
    required this.onTapDetail,
    required this.onTapRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final isIssued = state == _CouponState.issued;
    final canCopy = isIssued && code.isNotEmpty; // ✅ 미사용 & 코드 존재할 때만 복사 가능
    final actionLabel =
        isIssued ? '사용하기' : (state == _CouponState.redeemed ? '사용완료' : '만료됨');

    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) 상단: 제목 + 상태칩
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(state: state),
            ],
          ),
          const SizedBox(height: 10),

          // 2) 코드(한 줄) + 복사 아이콘
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text('코드',
                    style:
                        TextStyle(color: _label, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  code.isEmpty ? '(코드 없음)' : code,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: code.isEmpty ? 0 : 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: code.isEmpty ? _label : Colors.black,
                    height: 1.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: canCopy ? '코드 복사' : '복사 불가',
                onPressed: canCopy
                    ? () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('코드를 복사했어요.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null, // ✅ 사용완료/만료이면 비활성
                icon: Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: canCopy ? _brand : Colors.grey, // ✅ 색상도 비활성 톤
                ),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 3) 날짜들
          Row(
            children: [
              const Text('발급일', style: TextStyle(color: _label)),
              const SizedBox(width: 8),
              Text(issuedAt),
              if (state == _CouponState.redeemed) ...[
                const SizedBox(width: 18),
                const Text('사용일', style: TextStyle(color: _label)),
                const SizedBox(width: 8),
                Text(redeemedAt),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 4) 하단 액션: 좌측 쿠폰 보기, 우측 상태 버튼
          Row(
            children: [
              TextButton.icon(
                onPressed: onTapDetail,
                icon: const Icon(
                  Icons.confirmation_number_outlined, // ✅ 쿠폰(티켓) 아이콘
                  size: 18,
                ),
                // 필요 시 선물 아이콘으로 바꾸려면 ↓
                // icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                label: const Text('쿠폰 보기'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: isIssued ? onTapRedeem : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: isIssued ? _brand : Colors.grey.shade300,
                    foregroundColor: isIssued ? Colors.white : Colors.grey[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ===== 유틸: 안전한 Timestamp 포맷 =====
String _fmtTs(dynamic ts) {
  if (ts is Timestamp) {
    final dt = ts.toDate();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
  return '-';
}

/// ===== 상태 분류 & 칩 =====
enum _CouponState {
  issued,
  redeemed,
  expired;

  static _CouponState fromStatus(String status) {
    final s = status.toUpperCase();
    if (s == 'REDEEMED') return _CouponState.redeemed;
    if (s == 'EXPIRED') return _CouponState.expired;
    return _CouponState.issued;
  }
}

extension on _CouponState {
  Color get fg => switch (this) {
        _CouponState.issued => _info,
        _CouponState.redeemed => _ok,
        _CouponState.expired => _warn,
      };
  String get label => switch (this) {
        _CouponState.issued => '미사용',
        _CouponState.redeemed => '사용완료',
        _CouponState.expired => '만료됨',
      };
}

class _StatusChip extends StatelessWidget {
  final _CouponState state;
  const _StatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final c = state.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(
        state.label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

/// ===== 빈 상태 =====
class _EmptyState extends StatelessWidget {
  final VoidCallback onGoEvent;
  const _EmptyState({required this.onGoEvent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 64, color: _brand.withOpacity(.65)),
              const SizedBox(height: 12),
              const Text('아직 보유한 쿠폰이 없어요',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                '이벤트에 참여하고 지역 제휴 쿠폰을 받아보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _label),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onGoEvent,
                icon: const Icon(Icons.celebration_rounded),
                label: const Text('이벤트 보러가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공통 카드 데코
BoxDecoration _cardDeco() => BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );

/// 앱 공통 확인 다이얼로그(회색 배경, 우하단 버튼 정렬)
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  String cancelText = '취소',
  String confirmText = '확인',
  Color brand = const Color(0xFF304FFE),
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true, // 내비바까지 덮기
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(.30),
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      title: Row(
        children: [
          Icon(icon, color: brand, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
      content: Text(message,
          style: const TextStyle(color: Colors.black87, fontSize: 14)),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(cancelText),
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
