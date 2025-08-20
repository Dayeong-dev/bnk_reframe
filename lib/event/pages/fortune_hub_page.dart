import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/fortune_auth_service.dart';
import '../service/fortune_firestore_service.dart';
import 'start_page.dart';
import 'coupons_screen.dart'; // 스트림/알림 포함한 쿠폰 화면

class FortuneHubPage extends StatefulWidget {
  const FortuneHubPage({super.key});

  @override
  State<FortuneHubPage> createState() => _FortuneHubPageState();
}

class _FortuneHubPageState extends State<FortuneHubPage> {
  String? _uid;
  String? _inviter; // 딥링크나 상위 라우트에서 전달

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final me = await FortuneAuthService.ensureSignedIn();
    setState(() => _uid = me);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is Map) {
      _inviter = (raw['inviter'] ?? raw['inviteCode'] ?? raw['code'])?.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(title: const Text('운세 이벤트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 현재 스탬프 카운트
            if (uid == null)
              const Text('로그인 준비 중...', style: TextStyle(fontSize: 14))
            else
              StreamBuilder<int>(
                stream: FortuneFirestoreService.streamStampCount(uid),
                builder: (context, snap) {
                  final count = (snap.data ?? 0);
                  return Text('현재 스탬프: $count', style: const TextStyle(fontSize: 16));
                },
              ),

            const SizedBox(height: 20),

            // 운세 시작
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StartPage(),
                      settings: RouteSettings(arguments: {
                        if (_inviter != null) 'inviter': _inviter,
                      }),
                    ),
                  );
                },
                child: const Text('운세 시작'),
              ),
            ),

            const SizedBox(height: 12),

            // 쿠폰함 보기
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CouponsScreen()),
                  );
                },
                child: const Text('쿠폰함 보기'),
              ),
            ),

            const SizedBox(height: 12),

            // 초대 보상 동기화(선택)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () async {
                  final me = await FortuneAuthService.ensureSignedIn();
                  if (me == null) return;
                  final claimed = await FortuneFirestoreService
                      .claimPendingInvitesAndIssueRewards(inviterUid: me, batchSize: 10);
                  if (!mounted) return;
                  if (claimed > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('초대 보상 $claimed건 반영 완료!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('반영할 보상이 없습니다.')),
                    );
                  }
                },
                child: const Text('초대 보상 다시 동기화'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
