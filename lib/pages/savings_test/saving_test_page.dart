import 'package:flutter/material.dart';
import 'services/recommender.dart';
import 'screens/start_screen.dart';
import 'screens/question_screen.dart';
import 'screens/result_screen.dart';

class SavingsTestPage extends StatelessWidget {
  const SavingsTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      title: '예적금 추천기',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/savings_start',
      routes: {
        '/savings_start': (ctx) => StartScreen(),
        '/savings_question': (ctx) => QuestionScreen(),
        '/savings_result': (ctx) => ResultScreen(answers: []), // 임시 전달
      },
    );
  }
}
