import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/fortune_auth_service.dart';
import 'input_page.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  // ★ 테스트용: 하루 1회 제한을 우회하려면 true
  static const bool kBypassDailyLimitForTest = true; // 운영 시 false로 변경

  Future<bool> _checkDailyLimit(BuildContext context) async {
    // 테스트 우회
    if (kBypassDailyLimitForTest) return true;

    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) return true; // 로그인 안 된 경우 제한 불가 → InputPage에서 로그인 후 처리

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return true; // 새 유저 → 제한 없음

    final lastDrawDate = doc.data()?['lastDrawDate'];
    final today = DateTime.now();
    final todayStr =
        "${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}";

    if (lastDrawDate == todayStr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 오늘의 운세를 확인하셨습니다. 내일 다시 시도해주세요.')),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final raw = ModalRoute.of(context)?.settings.arguments;
    String? inviter;
    if (raw is Map) {
      inviter =
          (raw['inviter'] ?? raw['inviteCode'] ?? raw['code'])?.toString();
    }

    return Scaffold(
      // ✅ AppBar 추가
      appBar: AppBar(
        title: const Text('오늘의 운세'),
        centerTitle: true, // iOS/Android 모두 중앙 정렬
        elevation: 0.5, // 살짝 그림자
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('오늘의 운세를 확인해보세요', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () async {
              if (await _checkDailyLimit(context)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InputPage(),
                    settings: RouteSettings(arguments: {
                      if (inviter != null) 'inviter': inviter,
                    }),
                  ),
                );
              }
            },
            child: const Text('시작하기'),
          ),
        ]),
      ),
    );
  }
}
