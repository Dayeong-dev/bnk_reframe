import 'package:flutter/material.dart';

/// 앱 최상단 Navigator/ScaffoldMessenger 접근용 전역 키
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 필요 시 루트 컨텍스트로 Overlay 등에 접근할 때 사용
BuildContext? get rootContext => appNavigatorKey.currentContext;
