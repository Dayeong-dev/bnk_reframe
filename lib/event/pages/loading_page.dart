// lib/event/pages/loading_page.dart
import 'package:flutter/material.dart';
import '../models/types.dart';
import 'result_page.dart';

class LoadingPage extends StatefulWidget {
  final FortuneFlowArgs args;
  const LoadingPage({super.key, required this.args});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) _goResult();
    });
  }

  void _goResult() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(args: widget.args),
        settings: RouteSettings(arguments: {
          if (widget.args.invitedBy != null) 'inviter': widget.args.invitedBy,
        }),
      ),
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 200, height: 200, child: Image.asset('assets/images/fortune_gacha.gif', gaplessPlayback: true)),
            const SizedBox(height: 20),
            const Text("잠시만 기다려주세요...", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            TextButton(onPressed: _goResult, child: const Text("건너뛰고 결과 보기")),
          ]),
        ),
      ),
    );
  }
}
