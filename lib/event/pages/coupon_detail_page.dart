import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../service/fortune_firestore_service.dart';

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
    final docRef = FirebaseFirestore.instance.collection('coupons').doc(widget.couponId);

    return Scaffold(
      appBar: AppBar(title: const Text('쿠폰 상세')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? {};
          final title = (data['title'] ?? '[스타벅스] 아이스 아메리카노').toString();
          var code = (data['code'] ?? '').toString();
          final status = (data['status'] ?? 'ISSUED').toString();
          final isUsed = status.toUpperCase() == 'REDEEMED';

          // 첫 진입 시 코드가 없으면 생성해서 저장
          if (!_ensured && code.isEmpty) {
            _ensured = true;
            FortuneFirestoreService.ensureCouponCode(widget.couponId).then((c) {
              if (mounted) setState(() {});
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 이미지 (자산 사용, 없으면 아이콘 대체)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/starbucks_americano.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 220, height: 220,
                      color: Colors.green.shade50,
                      child: const Icon(Icons.local_cafe, size: 72, color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 18),

                // 큰 코드 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    code.isEmpty ? '코드 생성 중...' : code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 1.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: code.isEmpty ? null : () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('코드를 복사했어요.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('코드 복사'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: code.isEmpty ? null : () async {
                        await Share.share('스타벅스 쿠폰 코드: $code');
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('공유'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 사용하기
                if (!isUsed)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await FortuneFirestoreService.redeemCoupon(widget.couponId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('사용 완료 처리했습니다.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('사용하기'),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.green.withOpacity(.35)),
                    ),
                    child: const Text('이미 사용된 쿠폰입니다.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
