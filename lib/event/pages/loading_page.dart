import 'dart:async';
import 'package:flutter/material.dart';
import '../models/types.dart';
import '../service/fortune_api_service.dart';
import 'result_page.dart';

class LoadingPage extends StatefulWidget {
  final FortuneFlowArgs args;
  const LoadingPage({super.key, required this.args});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with TickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) _goResultIfReady();
    });

    // 백엔드 호출 시작
    _fetchFortune();
  }

  Future<void> _fetchFortune() async {
    try {
      final req = FortuneRequest(
        name: widget.args.name ?? '고객',
        birthDate: widget.args.birthDate ?? '',
        gender: widget.args.gender ?? '남',
        date: DateTime.now(), // 오늘
        invitedBy: widget.args.invitedBy,
      );
      final res = await FortuneApiService.getFortune(req);

      if (!mounted) return;
      _goResultWithData(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운세를 불러오는 중 문제가 발생했어요. 다시 시도해주세요.')),
      );
      // 실패 시에도 결과 페이지로 넘겨 임시 메시지 표시
      _goResultWithData(FortuneResponse(
        fortune: '계획을 점검하기 좋은 하루예요.',
        keyword: '안정',
        content: '큰 변화보다 작은 정리에 집중하면 좋아요. 오늘 할 일을 짧게 쪼개면 부담이 줄어요. 루틴을 정비하며 재충전해 보세요.', // ✅ 추가
        products: const [],
      ));
    }
  }

  void _goResultIfReady() {
    // 애니메이션 완료 시 필요한 추가 동작이 있으면 여기에
  }

  void _goResultWithData(FortuneResponse res) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(args: widget.args, data: res),
        settings: RouteSettings(arguments: {
          if (widget.args.invitedBy != null) 'inviter': widget.args.invitedBy,
        }),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 여백을 넉넉히 줘서 문구를 살짝 아래로
            const SizedBox(height: 80),

            // 상단 타이틀 (진회색)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '당신의 운세를\n확인하는 중입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242), // 진회색
                  height: 1.25,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ✅ 남는 공간을 기준으로 GIF가 자동으로 크게
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.cover, // 화면을 꽉 채우도록 설정
                    child: Image.asset(
                      'assets/images/fortune2.gif',
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
