// lib/pages/coupon_detail_page.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../service/fortune_firestore_service.dart';

const _brand = Color(0xFF2962FF);
const _cardBg = Color(0xFFF7F9FC);
const _border = Color(0xFFE5EAF1);

class CouponDetailPage extends StatefulWidget {
  final String couponId;
  const CouponDetailPage({super.key, required this.couponId});

  @override
  State<CouponDetailPage> createState() => _CouponDetailPageState();
}

class _CouponDetailPageState extends State<CouponDetailPage> {
  bool _ensured = false;

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('coupons').doc(widget.couponId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('쿠폰 상세'),
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: docRef.snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data();
              final title = (data?['title'] ?? '[스타벅스] 아이스 아메리카노').toString();
              final code = (data?['code'] ?? '').toString();
              return IconButton(
                tooltip: '공유',
                onPressed: () =>
                    Share.share(code.isEmpty ? title : '쿠폰($title) 코드: $code'),
                icon: const Icon(Icons.ios_share_rounded),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const _ErrorBox(message: '쿠폰 정보를 불러오지 못했어요.\n다시 시도해 주세요.');
          }
          if (!snap.hasData) {
            return const _SkeletonView();
          }

          final data = snap.data!.data() ?? {};
          final title = (data['title'] ?? '[스타벅스] 아이스 아메리카노').toString();
          var code = (data['code'] ?? '').toString();
          final status = (data['status'] ?? 'ISSUED').toString();
          final isUsed = status.toUpperCase() == 'REDEEMED';

          // 최초 진입 시 코드 생성(1회)
          if (!_ensured && code.isEmpty) {
            _ensured = true;
            FortuneFirestoreService.ensureCouponCode(widget.couponId).then((_) {
              if (mounted) setState(() {});
            });
          }

          return RefreshIndicator(
            color: _brand,
            onRefresh: () async =>
                Future<void>.delayed(const Duration(milliseconds: 300)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==== A. 히어로(여백 없이 꽉 채움) ====
                  _HeroCard(title: title, isUsed: isUsed),
                  const SizedBox(height: 16),

                  // ==== B. 코드 + 복사 아이콘(한 줄) ====
                  _InlineCodeRow(
                    code: code,
                    // ✅ 사용완료면 복사 비활성 / 코드 없으면 비활성
                    onCopy: (!isUsed && code.isNotEmpty)
                        ? () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('코드를 복사했어요.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 18),

                  // ==== C. 사용하기(아이콘 없이 텍스트만) ====
                  if (!isUsed)
                    _RedeemButton(
                      onConfirmRedeem: () async {
                        final ok = await showAppConfirmDialog(
                          context: context,
                          icon: Icons.check_circle_outline_rounded,
                          title: '쿠폰 사용하기',
                          message: '해당 쿠폰을 사용 처리할까요? 되돌릴 수 없어요.',
                          confirmText: '사용',
                        );
                        if (ok != true) return;

                        await FortuneFirestoreService.redeemCoupon(
                            widget.couponId);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('사용 완료 처리했습니다.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    )
                  else
                    const _UsedPill(),
                  const SizedBox(height: 24),

                  // ==== D. 이용 안내(아이콘-텍스트 줄맞춤 디테일) ====
                  _InfoSection(
                    items: const [
                      '직원에게 쿠폰 코드를 보여주고 사용 처리해 주세요.',
                      '일부 매장/프로모션에서는 사용이 제한될 수 있어요.',
                      '유효기간 내에만 사용 가능하며, 사용 처리 후 취소가 불가해요.',
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ====== UI 위젯들 ======

/// 여백 없이 꽉 찬 히어로 이미지 (BoxFit.cover), 상태 오버레이만 유지
class _HeroCard extends StatelessWidget {
  final String title;
  final bool isUsed;
  const _HeroCard({required this.title, required this.isUsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 높이 고정 + cover 로 레터박스 제거
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Image.asset(
              'assets/images/starbucks_americano.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.green.shade50,
                child: const Center(
                  child: Icon(Icons.local_cafe, size: 72, color: Colors.green),
                ),
              ),
            ),
          ),
          // 하단 가독성 그라데이션
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 제목만 좌하단
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ),
          // 사용완료 오버레이
          if (isUsed)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.6),
                child: const Center(
                  child:
                      Icon(Icons.lock_rounded, size: 64, color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 코드 한 줄 + 복사 아이콘(공유 버튼 없음)
class _InlineCodeRow extends StatelessWidget {
  final String code;
  final VoidCallback? onCopy;
  const _InlineCodeRow({required this.code, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // 긴 코드도 1줄로 보이되, 복사하려면 길게 눌러 드래그 가능(SelectableText)
          Expanded(
            child: SelectableText(
              code.isEmpty ? '코드 생성 중...' : code,
              maxLines: 1,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onCopy,
            tooltip: onCopy == null ? '복사 불가' : '복사',
            icon: Icon(
              Icons.copy_rounded,
              color: onCopy == null ? Colors.grey : _brand,
              size: 20,
            ),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

/// 사용하기 버튼(텍스트만)
class _RedeemButton extends StatelessWidget {
  final VoidCallback onConfirmRedeem;
  const _RedeemButton({required this.onConfirmRedeem});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          elevation: 0,
        ),
        onPressed: onConfirmRedeem,
        child: const Text('사용하기'),
      ),
    );
  }
}

class _UsedPill extends StatelessWidget {
  const _UsedPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2E6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(.35)),
        ),
        child: const Text(
          '이미 사용된 쿠폰입니다.',
          style: TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// 이용 안내(체크 아이콘과 텍스트 줄맞춤 정밀)
class _InfoSection extends StatelessWidget {
  final List<String> items;
  const _InfoSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이용 안내',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.black)),
          const SizedBox(height: 8),
          ...items.map((t) => _InfoItem(text: t)),
        ],
      ),
    );
  }
}

/// 아이콘이 **첫 줄 기준**으로 정렬되도록 세심하게 맞춘 항목
class _InfoItem extends StatelessWidget {
  final String text;
  const _InfoItem({required this.text});

  @override
  Widget build(BuildContext context) {
    // 아이콘 상단을 텍스트 첫 줄과 맞추기 위해 작은 top padding 적용
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 첫 줄 기준 정렬감 보정: size 18 + top 2
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: const Icon(Icons.check_circle, size: 18, color: _brand),
          ),
          const SizedBox(width: 8),
          // 줄간격/폭 최적화
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF424242),
                height: 1.45, // 여러 줄 때 가독성 좋게
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공통 카드 데코
BoxDecoration _cardDeco() => BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );

/// 스켈레톤
class _SkeletonView extends StatelessWidget {
  const _SkeletonView();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h) => Container(
          height: h,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Container(
          decoration: _cardDeco(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(height: 280, child: bar(280)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: _cardDeco(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(child: bar(24)),
            const SizedBox(width: 8),
            bar(24)
          ]),
        ),
        const SizedBox(height: 18),
        SizedBox(height: 52, child: bar(52)),
        const SizedBox(height: 24),
        Container(
          decoration: _cardDeco(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              bar(18),
              const SizedBox(height: 10),
              bar(18),
              const SizedBox(height: 10),
              bar(18),
            ],
          ),
        ),
      ],
    );
  }
}

/// 에러 박스
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

/// ===== 앱 공통 확인 다이얼로그 (리스트 페이지와 동일 스타일) =====
/// - 회색 오버레이, 내비바까지 덮기(useRootNavigator: true)
/// - 제목 앞 아이콘 + 볼드 제목
/// - 버튼 우하단 정렬, 라운드 10
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  String cancelText = '취소',
  String confirmText = '확인',
  Color brand = _brand, // 이 파일의 _brand 사용
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true, // ✅ 내비바까지 덮기
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
