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
                      fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
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
                    onPressed: () => Navigator.pushNamed(context, '/savings/question'),
                    child: const Text('테스트 시작', style: TextStyle(fontSize: 18)),
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
