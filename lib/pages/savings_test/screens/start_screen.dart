// lib/pages/start_screen.dart
import 'package:flutter/material.dart';
import 'question_screen.dart';

class StartScreen extends StatelessWidget {
  static const routeName = '/';
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '저축하고 싶은데\n예적금 선택이 어렵다면?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: Image.asset(
                    'assets/images/pig2.png',
                    fit: BoxFit.contain,
                    width: 260,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32), // 여백 늘리기
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // 둥근 모서리 (선택)
                      ),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/savings/question'),
                    child: const Text(
                        '시작하기',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
