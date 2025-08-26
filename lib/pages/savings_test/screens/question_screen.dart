// lib/pages/question_screen.dart
import 'package:flutter/material.dart';
import 'package:reframe/app/app_shell.dart';
import '../services/recommender.dart';
import 'result_screen.dart';

class QuestionScreen extends StatefulWidget {
  static const routeName = '/savings/question';
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // 현재 문제 인덱스 (0~3)
  int step = 0;
  static const int totalSteps = 4;

  final List<String?> answers = List.filled(totalSteps, null);

  // 진행률(0.0~1.0) - 처음엔 0부터 시작
  double get progress => step / totalSteps;

  void _selectAndNext(String value) {
    answers[step] = value;
    setState(() {}); // 선택 표시 업데이트

    // 살짝 딜레이 후 다음 문제/결과로 이동
    Future.delayed(const Duration(milliseconds: 120), () {
      if (step < totalSteps - 1) {
        setState(() => step += 1); // 다음 문제로
      } else {
        final code = getRecommendationCode(answers.cast<String>());
        Navigator.pushNamed(context, '/savings/result', arguments: code);
      }
    });
  }

  /// ✅ 뒤로가기 커스텀:
  /// - step>0: 라우트 pop 대신 문제 인덱스만 줄임
  /// - step==0: 실제 pop 허용
  Future<bool> _handleBack() async {
    if (step > 0) {
      setState(() => step -= 1);
      return false;
    }
    return true;
  }

  // === 리뷰페이지와 통일된 스타일의 확인 다이얼로그 ===
  Future<bool> _showExitConfirmDialog() async {
    final primary = Theme.of(context).colorScheme.primary;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              '테스트 종료',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        content: const Text(
          '정말로 테스트를 중단하고 홈으로 나가시겠습니까?',
          style: TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          // 취소(회색 텍스트 버튼)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('취소'),
          ),
          // 나가기(브랜드 컬러로 통일)
          ElevatedButton(
            onPressed: () {
              // 스택 비우고 AppShell을 예적금 탭(initialTab: 1)으로 시작
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const AppShell(initialTab: 1)),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // 세로(가로 꽉 채우는) 버튼
  Widget _option(String label) {
    final selected = answers[step] == label;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isPressed = false;

        // 상태별 색상 정의
        final bool active = selected || isPressed; // 클릭 중이거나 선택된 상태
        final Color bg = active ? primary : Colors.white;
        final Color edge = active ? primary : Colors.grey.shade400;
        final Color textColor = active ? Colors.white : Colors.black87;

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
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: edge, width: 2),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("예적금 추천"),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () async {
                final goHome = await _showExitConfirmDialog();
                if (!mounted || !goHome) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
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
                // ✅ 한 줄 진행바 + 진행 텍스트
                _LinearProgressWithLabel(
                  value: progress, // 0.0 ~ 1.0
                  label: '${step}/${totalSteps}', // 예: 0/4, 1/4 ...
                  barColor: primary, // 프라이머리 컬러
                  trackColor: Colors.white, // 배경(흰색 또는 회색)
                  borderColor: Colors.grey.shade300,
                  height: 10,
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

/// ===============================================
/// 한 줄 진행바 + 텍스트 라벨
/// - value: 0.0~1.0 (0부터 시작)
/// - label: 진행 텍스트("0/4" 등)
/// - barColor: 채워질 색(프라이머리)
/// - trackColor: 배경(흰색/회색)
/// ===============================================
class _LinearProgressWithLabel extends StatelessWidget {
  final double value;
  final String label;
  final double height;
  final Color barColor;
  final Color trackColor;
  final Color borderColor;

  const _LinearProgressWithLabel({
    required this.value,
    required this.label,
    required this.barColor,
    required this.trackColor,
    required this.borderColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 진행바
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // 트랙(배경)
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: trackColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // 채워진 바 (애니메이션)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth * value.clamp(0.0, 1.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      height: height,
                      width: w,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 진행 텍스트
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
