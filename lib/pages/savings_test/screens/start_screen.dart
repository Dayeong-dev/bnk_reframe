import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'question_screen.dart';

class StartScreen extends StatefulWidget {
  static const routeName = '/savings/start';
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with TickerProviderStateMixin {
  late final AnimationController _textController; // 문장 전체 페이드
  late final AnimationController _popController;  // 이미지 팝(커졌다 작아짐)

  @override
  void initState() {
    super.initState();

    // 페이드 더 천천히
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..forward();

    // 팝 효과: 0.94x ~ 1.06x 사이에서 부드럽게 왕복
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = '저축하고 싶은데\n예적금 선택이 어렵다면?';

    final fade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    );

    // 팝 효과 곡선 + 스케일 범위
    final popCurve = CurvedAnimation(
      parent: _popController,
      curve: Curves.easeInOut,
    );
    final popScale = Tween<double>(begin: 0.94, end: 1.06).animate(popCurve);

    return Scaffold(
      appBar: AppBar(
        title: const Text('시작하기'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 상단 텍스트: 문장 전체 페이드(느리게)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: FadeTransition(
                opacity: fade,
                child: const Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF424242), // 진회색
                    height: 1.25,
                  ),
                ),
              ),
            ),

            // 중간 이미지: 팝 효과(스케일 업/다운)
            Expanded(
              child: Center(
                child: ScaleTransition(
                  scale: popScale,
                  child: Image.asset(
                    'assets/images/pig2.png',
                    width: 300,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.only(
                bottom: 40,
                left: 24,
                right: 24,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 18),
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/savings/question'),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
