import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:reframe/app/app_shell.dart'; // ✅ 네비바 포함된 쉘
import 'package:reframe/constants/color.dart';
import 'package:reframe/pages/home_page.dart'; // (미사용 가능, 필요 시 유지)

class SuccessEnrollPage extends StatelessWidget {
  const SuccessEnrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // ✅ 테마 참조

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ 성공 애니메이션 (색상 델리게이트는 기존 그대로)
              SizedBox(
                width: 200,
                height: 200,
                child: LottieBuilder.asset(
                  'assets/images/success.json',
                  width: 200,
                  fit: BoxFit.contain,
                  repeat: false,
                  animate: true,
                  key: ValueKey('succ-${primaryColor.value}-${subColor.value}'),
                  delegates: LottieDelegates(values: [
                    ValueDelegate.color(
                      ['Shape Layer 1', 'Ellipse 1', 'Fill 1'],
                      value: subColor,
                    ),
                    ValueDelegate.color(
                      ['Shape Layer 2', 'Ellipse 1', 'Fill 1'],
                      value: primaryColor,
                    ),
                    ValueDelegate.color(
                      ['check', 'Shape 1', 'Stroke 1'],
                      value: Colors.white,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "상품가입 완료!",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 60),

              // ✅ 테마 기본색을 쓰는 버튼 + 누르면 네비바 있는 AppShell로 이동
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // 스택을 비우고 네비바 포함된 쉘로 진입
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) =>
                            const AppShell(), // AppShell이 BottomNav 제공
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    // 앱의 기본 Primary/OnPrimary 사용
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "가입 내역 보러가기",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
