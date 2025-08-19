// lib/pages/question_screen.dart
import 'package:flutter/material.dart';
import '../services/recommender.dart';
import 'result_screen.dart';

class QuestionScreen extends StatefulWidget {
  static const routeName = '/savings/question';
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int step = 0;

  // 사용자가 선택한 "문자열"을 그대로 저장(호환 함수 사용)
  final List<String?> answers = List.filled(4, null);

  double get progress => (step + 1) / 4;

  void _select(String value) {
    answers[step] = value;
    setState(() {});
  }

  void _next() {
    if (step < 3) {
      setState(() => step += 1);
      return;
    }
    // 최종: 문자열 리스트 → A~H 코드
    final code = getRecommendationCode(answers.cast<String>());
    Navigator.pushNamed(context, '/savings/result', arguments: code);
  }

  Widget _option(String label) {
    final selected = answers[step] == label;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade400),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _select(label),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: selected ? Colors.blue : Colors.black87,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 정의서 문구 그대로
    const titles = <String>[
      '당신의 저축 목표는?',
      '당신의 저축 스타일은?',
      '중도에 해지할 가능성이 있나요',
      '저축 습관을 형성하고 싶으신가요?',
    ];

    final options = <List<String>>[
      ['단기간 목돈 마련', '안정적인 이자 수익'],
      ['한 번에 크게 저축', '매달 조금씩 저축'],
      ['없다', '상황에 따라 필요할 수도'],
      ['네', '아니오'],
    ];

    final canNext = answers[step] != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                titles[step],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const Spacer(),
              Row(
                children: [
                  _option(options[step][0]),
                  const SizedBox(width: 12),
                  _option(options[step][1]),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: canNext ? _next : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(step < 3 ? '다음' : '결과 보기', style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
