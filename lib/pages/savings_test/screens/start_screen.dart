import 'package:flutter/material.dart';
import 'question_screen.dart';

class StartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '예적금 맞춤 추천 테스트',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              Text(
                '간단한 질문에 답하면\n당신에게 맞는 예적금 상품을 추천해드릴게요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => QuestionScreen()),
                  );
                },
                child: Text('시작하기', style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
