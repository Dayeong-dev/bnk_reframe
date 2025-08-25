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
    setState(() {}); // 선택 표시 업데이트
    Future.delayed(const Duration(milliseconds: 120), () {
      if (step < 3) {
        setState(() => step += 1);
      } else {
        final code = getRecommendationCode(answers.cast<String>());
        Navigator.pushNamed(context, '/savings/result', arguments: code);
      }
    });
  }

  // ✅ 공통 '뒤로가기' 처리:
  // - step > 0 이면 이전 문제로만 이동 (Route pop 안 함)
  // - step == 0 이면 true 반환해서 실제 pop 허용
  Future<bool> _handleBack() async {
    if (step > 0) {
      setState(() => step -= 1);
      return false; // pop 막음 (같은 화면에서 이전 문제로만)
    }
    return true; // 첫 문제면 실제로 이전 화면으로 pop
  }

  // 세로(가로 꽉 채우는) 버튼
  Widget _option(String label) {
    final selected = answers[step] == label;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isPressed = false;

        final Color baseBg = selected ? Colors.grey[200]! : Colors.white;
        final Color pressedBg = Colors.grey[300]!;
        final Color edge = selected ? Colors.grey : Colors.grey.shade400;

        return SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onHighlightChanged: (v) => setLocalState(() => isPressed = v),
              onTap: () => _selectAndNext(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPressed ? pressedBg : baseBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: edge, width: 2),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
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
      'assets/images/q1.gif',
      'assets/images/q2.gif',
      'assets/images/q3.gif',
      'assets/images/q4.gif',
    ];

    final screenW = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: _handleBack, // ✅ 시스템/제스처 뒤로가기 커스텀
      child: Scaffold(
        appBar: AppBar(
          title: const Text("예적금 추천"),
          // 왼쪽 ← 뒤로가기는 자동으로 유지됨
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("확인"),
                    content: const Text("정말로 테스트를 중단하고 나가시겠습니까?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context), // 닫기
                        child: const Text("취소"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // 알럿 닫기
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/', // 홈 라우트
                            (route) => false,
                          );
                        },
                        child: const Text("나가기"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
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
                  ),
                ),

                const SizedBox(height: 60),

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

                // 이미지
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: screenW * 0.7,
                      height: screenW * 0.7,
                      child: Image.asset(
                        images[step],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 답변 버튼 (세로 배치)
                _option(options[step][0]),
                const SizedBox(height: 12),
                _option(options[step][1]),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
