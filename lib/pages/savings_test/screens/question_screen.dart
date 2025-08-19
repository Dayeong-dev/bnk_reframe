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

  final List<String?> answers = List.filled(4, null);
  double get progress => (step + 1) / 4;

  void _selectAndNext(String value) {
    answers[step] = value;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 120), () {
      if (step < 3) {
        setState(() => step += 1);
      } else {
        final code = getRecommendationCode(answers.cast<String>());
        Navigator.pushNamed(context, '/savings/result', arguments: code);
      }
    });
  }

  // 세로(가로 꽉 채우는) 버튼
  Widget _option(String label) {
    final selected = answers[step] == label;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isPressed = false;

        final Color baseBg   = selected ? Colors.grey[200]! : Colors.white; // 평상시 배경
        final Color pressedBg = Colors.grey[300]!;                           // 클릭 중 배경
        final Color edge     = selected ? Colors.grey : Colors.grey.shade400; // 테두리 유지

        return SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onHighlightChanged: (v) => setLocalState(() => isPressed = v), // 눌림 감지
              onTap: () => _selectAndNext(label),
              // 리플은 유지되고, 배경은 AnimatedContainer로 제어
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPressed ? pressedBg : baseBg, // 클릭 순간만 연회색
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: edge, width: 2), // 테두리 그대로
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black, // 글자색 그대로
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    const titles = <String>[
      '저축할 때,\n당신의 목표는?',
      '당신의 저축 스타일은?',
      '중도 해지 가능성이 있나요?',
      '저축 습관을 \n형성하고 싶으신가요?',
    ];

    final options = <List<String>>[
      ['단기간 목돈 마련', '안정적인 이자 수익'],
      ['한 번에 크게 저축', '매달 조금씩 저축'],
      ['없다', '상황에 따라 필요할 수도'],
      ['네', '아니오'],
    ];

    const images = <String>[
      'assets/images/q1.jpg',
      'assets/images/q2.png',
      'assets/images/q3.jpg',
      'assets/images/q4.jpg',
    ];

    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 진행바
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                ),
              ),

              const SizedBox(height: 80), // ← 진행바와 질문 텍스트 간격 넓힘

              // 질문 텍스트
              Text(
                titles[step],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // 이미지: 화면 가운데에 오도록 Expanded+Center
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: screenW * 0.7,      // 화면 폭의 70%
                    height: screenW * 0.7,     // 정사각 영역(디자인에 맞게 조정 가능)
                    child: Image.asset(
                      images[step],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // 버튼을 너무 아래로 내리지 않도록 여백만 살짝
              const SizedBox(height: 8),

              // 답변 버튼 (세로 배치)
              _option(options[step][0]),
              const SizedBox(height: 12),
              _option(options[step][1]),

              const SizedBox(height: 12), // 하단 안전 여백
            ],
          ),
        ),
      ),
    );
  }
}
