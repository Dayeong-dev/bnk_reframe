import 'package:flutter/material.dart';
import '../services/recommender.dart';

class ResultScreen extends StatelessWidget {
  final List<String> answers;

  ResultScreen({required this.answers});

  @override
  Widget build(BuildContext context) {
    final code = getRecommendationCode(answers);
    final resultText = getRecommendationText(code);

    return Scaffold(
      appBar: AppBar(title: Text("추천 결과")),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('추천 코드: $code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text(
                resultText,
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: Text('처음으로', style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
