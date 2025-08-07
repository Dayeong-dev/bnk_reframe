import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class StepDebugPage extends StatefulWidget {
  const StepDebugPage({super.key});

  @override
  State<StepDebugPage> createState() => _StepDebugPageState();
}

class _StepDebugPageState extends State<StepDebugPage> {
  final Health _health = Health();
  String _status = "앱 실행됨";

  Future<void> _checkPermissions() async {
    setState(() => _status = "권한 확인 중...");

    if (Platform.isAndroid) {
      if (await Permission.activityRecognition.isDenied) {
        await Permission.activityRecognition.request();
      }
    }

    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    final hasPerm = await _health.hasPermissions(types, permissions: permissions);
    debugPrint("현재 권한 상태: ${hasPerm ?? false}");

    final granted = await _health.requestAuthorization(types, permissions: permissions);
    debugPrint("권한 요청 결과: $granted");

    if (granted) {
      _fetchSteps();
    } else {
      setState(() => _status = "❌ Health Connect 권한 없음 (앱 등록 안 됐을 수 있음)");
    }
  }

  Future<void> _fetchSteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    int? steps = await _health.getTotalStepsInInterval(midnight, now);
    debugPrint("오늘 걸음 수: ${steps ?? 0}");

    setState(() => _status = "오늘 걸음 수: ${steps ?? 0} 보");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('걸음 수 디버깅')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkPermissions,
              child: const Text('권한 확인 및 요청'),
            ),
          ],
        ),
      ),
    );
  }
}
