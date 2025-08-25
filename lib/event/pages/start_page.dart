// lib/event/pages/start_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/fortune_auth_service.dart';
import 'input_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with SingleTickerProviderStateMixin {
  static const bool kBypassDailyLimitForTest = true;

  late final AnimationController _ctrl;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _textOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> _checkDailyLimit(BuildContext context) async {
    if (kBypassDailyLimitForTest) return true;

    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) return true;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return true;

    final lastDrawDate = doc.data()?['lastDrawDate'];
    final today = DateTime.now();
    final todayStr =
        "${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}";

    if (lastDrawDate == todayStr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 오늘의 운세를 확인하셨습니다. 내일 다시 시도해주세요.')),
        );
      }
      return false;
    }
    return true;
  }

  double _dxFor(double t) {
    const amplitude = 16.0;
    const freq = 4;
    final damping = (1 - t);
    return math.sin(2 * math.pi * freq * t) * amplitude * damping;
  }

  @override
  Widget build(BuildContext context) {
    final raw = ModalRoute.of(context)?.settings.arguments;
    String? inviter;
    if (raw is Map) {
      inviter = (raw['inviter'] ?? raw['inviteCode'] ?? raw['code'])?.toString();
    }

    return Scaffold(
      appBar: AppBar(centerTitle: true, elevation: 0.5),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 상단 텍스트 (페이드 인)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Opacity(
                    opacity: _textOpacity.value,
                    child: const Text(
                      '오늘의 운세를\n확인해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 중간 이미지 (좌우 흔들림 + 살짝 페이드)
                Expanded(
                  child: Center(
                    child: Opacity(
                      opacity: 0.3 + 0.7 * Curves.easeOut.transform(t),
                      child: Transform.translate(
                        offset: Offset(_dxFor(t), 0),
                        child: Image.asset(
                          'assets/images/f1.png',
                          width: 500,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단 버튼
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                      child: const Text(
                        '시작하기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
