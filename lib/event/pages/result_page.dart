import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../pages/deposit/deposit_detail_page.dart';
import '../config/share_links.dart';
import '../models/types.dart';
import '../service/fortune_auth_service.dart';

class ResultPage extends StatefulWidget {
  final FortuneFlowArgs args;
  final FortuneResponse data;
  const ResultPage({super.key, required this.args, required this.data});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Future<void> _shareFortune() async {
    await FortuneAuthService.ensureSignedIn();
    final myUid = FortuneAuthService.getCurrentUid();
    if (myUid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인을 다시 시도해주세요.')),
      );
      return;
    }

    final appLink = ShareLinks.shareUrl(inviteCode: myUid, src: 'result');
    final playStore = ShareLinks.playStoreUrl;

    final text = StringBuffer()
      ..writeln('✨ 오늘의 운세')
      ..writeln()
      ..writeln(widget.data.fortune)
      ..writeln()
    // ✅ 부가설명(있으면)
      ..writeln((widget.data.content ?? '').isNotEmpty ? widget.data.content : '')
      ..writeln()
      ..writeln('추천 상품')
      ..writeln(widget.data.products.map((p) => '- ${p.name} (${p.category})').join('\n'))
      ..writeln()
      ..writeln(appLink)
      ..writeln()
      ..writeln('설치가 필요하면 ➜ $playStore');

    await Share.share(text.toString(), subject: '오늘의 운세를 확인해보세요!');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = "${now.month}월 ${now.day}일"; // 오늘 날짜

    return Scaffold(
      appBar: AppBar(title: const Text("오늘의 운세 결과")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 운세 메시지 위젯 (날짜 + '오늘은' + 운세 메시지)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F3D8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // 날짜 + 오늘은
                    Text(
                      '$formattedDate 오늘은',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 운세 메시지 (연회색, 작은 글씨)
                    Text(
                      widget.data.fortune,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.grey, // 연회색
                        height: 1.4,
                      ),
                    ),

                    if ((widget.data.content ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.data.content!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 운세 메시지와 이름 멘트 사이 여백
              const SizedBox(height: 24),

              // 고객 이름 멘트
              Text(
                '${widget.args.name} 님에게 추천드려요!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // 추천 상품 리스트 (각 카드 전체 탭 → 상세 페이지 이동)
              if (widget.data.products.isNotEmpty)
                ...widget.data.products.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DepositDetailPage(productId: p.productId),
                            settings: const RouteSettings(name: '/deposit/detail'),
                          ),
                        );
                      },
                      child: _ProductCard(
                        name: p.name,
                        summary: p.summary ?? '',
                      ),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 32),

              // 공유 버튼 (StartPage 스타일 느낌)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _shareFortune,
                  child: const Text(
                    "친구에게 공유하기",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 추천 상품 카드 (전체 탭 가능)
class _ProductCard extends StatelessWidget {
  final String name;
  final String summary;
  const _ProductCard({
    required this.name,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}
