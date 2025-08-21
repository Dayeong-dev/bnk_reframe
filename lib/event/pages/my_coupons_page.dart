import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import 'coupon_detail_page.dart';

class MyCouponsPage extends StatelessWidget {
  const MyCouponsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내 쿠폰함')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FortuneFirestoreService.streamCoupons(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('아직 보유한 쿠폰이 없어요.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final title = (data['title'] ?? '이벤트 쿠폰').toString();
              final code = (data['code'] ?? '').toString();
              final status = (data['status'] ?? 'ISSUED').toString();
              final issuedAt = _fmtTs(data['issuedAt']);
              final redeemedAt = _fmtTs(data['redeemedAt']);

              final isUsed = status.toUpperCase() == 'REDEEMED';

              return Card(
                elevation: 0,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 타이틀 + 상태 뱃지
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 코드
                      Row(
                        children: [
                          const Text('코드', style: TextStyle(color: Colors.black54)),
                          const SizedBox(width: 8),
                          SelectableText(
                            code.isEmpty ? '(코드 없음)' : code,
                            style: const TextStyle(fontSize: 15),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: '코드 복사',
                            onPressed: code.isEmpty
                                ? null
                                : () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('코드를 복사했어요.')),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 날짜들
                      Row(
                        children: [
                          const Text('발급일', style: TextStyle(color: Colors.black54)),
                          const SizedBox(width: 8),
                          Text(issuedAt),
                          if (isUsed) ...[
                            const SizedBox(width: 18),
                            const Text('사용일', style: TextStyle(color: Colors.black54)),
                            const SizedBox(width: 8),
                            Text(redeemedAt),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 액션버튼
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final shareText = StringBuffer()
                                ..writeln('🎁 쿠폰 공유')
                                ..writeln(title)
                                ..writeln(code.isEmpty ? '(코드 없음)' : '코드: $code');
                              await Share.share(shareText.toString());
                            },
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            label: const Text('공유'),
                          ),
                          if (!isUsed)
                            FilledButton.icon(
                              onPressed: () async {
                                await FortuneFirestoreService.redeemCoupon(d.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('사용 완료 처리했습니다.')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('사용하기'),
                            ),
                          // ✅ 상세보기(이미지 + 큰 코드 화면)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CouponDetailPage(couponId: d.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_2, size: 18),
                            label: const Text('쿠폰보기'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _fmtTs(dynamic ts) {
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
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final color = s == 'REDEEMED'
        ? Colors.green
        : s == 'EXPIRED'
        ? Colors.red
        : Colors.blue;
    final label = s == 'REDEEMED'
        ? '사용완료'
        : s == 'EXPIRED'
        ? '만료됨'
        : '미사용';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
