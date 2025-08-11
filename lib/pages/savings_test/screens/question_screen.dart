import 'package:flutter/material.dart';
import 'result_screen.dart';

class Question {
  final String title;
  final List<String> options;

  Question({required this.title, required this.options});
}

class QuestionScreen extends StatefulWidget {
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int _currentIndex = 0;
  List<String> _answers = [];

  final List<Question> _questions = [
    Question(title: '당신의 목표는?', options: [
      '단기간 목돈 마련',
      '안정적인 이자 수익',
    ]),
    Question(title: '한 번에 예치 가능? or 매달 저축?', options: [
      '한 번에 예치',
      '매달 저축',
    ]),
    Question(title: '중도 해지 가능성 있나요?', options: [
      '없다',
      '상황에 따라 필요할 수도',
    ]),
    Question(title: '저축 습관을 형성하고 싶나요?', options: [
      '네',
      '아니오',
    ]),
  ];

  void _selectOption(String answer) {
    _answers.add(answer);

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(answers: _answers),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text("질문 ${_currentIndex + 1}/${_questions.length}")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ...question.options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                onPressed: () => _selectOption(opt),
                child: Text(opt, style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(48),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
