import 'package:flutter/material.dart';
import 'question_screen.dart';

class StartScreen extends StatelessWidget {
  static const routeName = '/';
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 상단 텍스트
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Text(
                '저축하고 싶은데\n예적금 선택이 어렵다면?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),

            // 중간 이미지
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/pig2.png',
                  width: 300,
                  fit: BoxFit.contain,
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/savings/question'),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
