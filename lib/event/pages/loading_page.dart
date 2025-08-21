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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
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
        products: const [],
      ));
    }
  }

  void _goResultIfReady() {
    // 애니메이션이 끝났을 때만 동작하도록 유지 (실제 네비는 _fetchFortune에서 처리)
    // 별도 로직 불필요, 안전빵용
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
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 200, height: 200, child: Image.asset('assets/images/fortune_gacha.gif', gaplessPlayback: true)),
            const SizedBox(height: 20),
            const Text("운세 뽑는 중...", style: TextStyle(fontSize: 18, color: Colors.grey,)),
          ]),
        ),
      ),
    );
  }
}
