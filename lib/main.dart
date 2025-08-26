// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:reframe/constants/color.dart';
import 'package:reframe/pages/auth/join_page.dart';
import 'package:reframe/pages/auth/login_page.dart';
import 'package:reframe/pages/auth/splash_page.dart';
import 'package:reframe/pages/branch/map_page.dart';
import 'package:reframe/pages/customer/more_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/enroll/enroll_first.dart';
import 'package:reframe/pages/enroll/enroll_second.dart';
import 'package:reframe/pages/home_page.dart';
import 'package:reframe/pages/walk/step_debug_page.dart';
import 'package:reframe/service/firebase_service.dart';
import 'package:reframe/pages/chat/bnk_chat_page.dart';

// ── 운세 이벤트: Firebase/딥링크/페이지들 ────────────────────────────────
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event/service/fortune_auth_service.dart';
import 'event/service/deep_link_service.dart';
import 'event/pages/start_page.dart';
import 'event/pages/coupons_page.dart';

// ── Savings 테스트 페이지 임포트 ────────────────────────────────────────
import 'package:reframe/pages/savings_test/screens/start_screen.dart';
import 'package:reframe/pages/savings_test/screens/question_screen.dart';
import 'package:reframe/pages/savings_test/screens/result_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'event/core/live_coupon_announcer.dart';

// ✅ 기존 전역 네비게이터 키
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 날짜 포맷 로케일 데이터 로드
  await initializeDateFormatting('ko_KR', null);

  // 2) 네이버 지도 SDK 초기화
  await FlutterNaverMap().init(
    clientId: '1vyye633d9',
    onAuthFailed: (e) => debugPrint('❌ 지도 인증 실패: $e'),
  );

  // 3) Firebase Core 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4) 운세 기능: 익명 로그인 보장
  try {
    await FortuneAuthService.ensureSignedIn();
    debugPrint('✅ 익명 로그인 보장 완료');
  } catch (e, st) {
    debugPrint('🔥 익명 로그인 실패: $e\n$st');
  }

  // 5) 기존 FirebaseService(Analytics 등) 초기화
  final firebaseService = await FirebaseService.init(
    forceRefreshToken: true,
  );

  runApp(MyApp(firebaseService: firebaseService));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await LiveCouponAnnouncer.I.start();
    } catch (e) {
      debugPrint('⚠️ LiveCouponAnnouncer start failed: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseService});
  final FirebaseService firebaseService;

  @override
  Widget build(BuildContext context) {
    return DeepLinkBootstrapper(
      child: MaterialApp(
        // ✅ 루트 네비게이터에 전역 키 장착
        navigatorKey: navigatorKey,
        title: "BNK 부산은행",
        debugShowCheckedModeBanner: false,
        navigatorObservers: firebaseService.observers,

        // ✅ glow 제거 + 바운스 유지(안드/ios 모두)
        scrollBehavior: const AppScrollBehavior(),

        home: SplashPage(),
        routes: {
          "/home": (context) => const HomePage(),
          "/join": (context) => const JoinPage(),
          "/login": (context) => const LoginPage(),
          "/depositList": (context) => const DepositListPage(),
          "/depositMain": (context) => DepositMainPage(),
          "/step-debug": (context) => StepDebugPage(),
          "/chat-debug": (context) => BnkChatScreen(),
          "/more-page": (context) => MorePage(),
          '/map': (context) => const MapPage(),
          // Savings 테스트 라우트
          '/savings/start': (_) => const StartScreen(),
          '/savings/question': (_) => const QuestionScreen(),
          '/savings/result': (_) => const ResultScreen(),

          // 운세 이벤트 네임드 라우트
          '/event/fortune': (_) => const StartPage(),
          '/event/coupons': (_) => const CouponsPage(stampCount: 0),
        },

        // 👇 전역 AppBar/버튼/폼 스타일
        theme: ThemeData(
          useMaterial3: false,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            surface: Colors.white,
            background: Colors.white,
          ),

          // ✅ 전역 Card 모양/색 고정
          cardTheme: const CardThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent, // M3 대비용(지금은 M2라 무시)
            elevation: 0.6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),

          // AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            // ✅ StatusBar 색상/아이콘 색상 지정
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.white, // 상단 영역 배경 흰색
              statusBarIconBrightness: Brightness.dark, // 안드로이드: 검정 아이콘
              statusBarBrightness: Brightness.light, // iOS: 검정 아이콘
            ),
          ),

          // 버튼
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),

          // 폼 포커스
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
          ),

          // 체크/라디오/스위치(민트 방지)
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) return primaryColor;
              return Colors.white; // 비선택 시 배경 흰색
            }),
            checkColor: MaterialStateProperty.all<Color>(Colors.white),
            side: const BorderSide(color: Color(0xFFE0E3E7)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          radioTheme: RadioThemeData(
            fillColor: MaterialStateProperty.all(primaryColor),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: MaterialStateProperty.resolveWith((s) =>
                s.contains(MaterialState.selected)
                    ? Colors.white
                    : const Color(0xFFBDBDBD)),
            trackColor: MaterialStateProperty.resolveWith((s) =>
                s.contains(MaterialState.selected)
                    ? primaryColor
                    : const Color(0xFFE0E0E0)),
          ),

          // 성별 선택이 ToggleButtons라면 톤 통일
          toggleButtonsTheme: ToggleButtonsThemeData(
            selectedColor: Colors.white,
            color: Colors.black,
            fillColor: primaryColor.withOpacity(0.18),
            selectedBorderColor: primaryColor,
            borderColor: const Color(0xFFE0E3E7),
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
          ),
        ),
      ),
    );
  }
}

/// 앱 전역 딥링크 초기화/라우팅 부트스트랩퍼
class DeepLinkBootstrapper extends StatefulWidget {
  const DeepLinkBootstrapper({super.key, required this.child});
  final Widget child;

  @override
  State<DeepLinkBootstrapper> createState() => _DeepLinkBootstrapperState();
}

class _DeepLinkBootstrapperState extends State<DeepLinkBootstrapper> {
  final _deepLinks = DeepLinkService();
  bool _navigatedFromLink = false;

  @override
  void initState() {
    super.initState();

    _deepLinks.init((uri) async {
      final me = await FortuneAuthService.ensureSignedIn();

      final inviter = uri.queryParameters['inviter'];
      final code =
          uri.queryParameters['code'] ?? uri.queryParameters['inviteCode'];
      final inviterOrCode = inviter ?? code;

      if (!_navigatedFromLink) {
        _navigatedFromLink = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = navigatorKey.currentState;
          if (nav == null) return;
          nav.push(
            MaterialPageRoute(
              builder: (_) => const StartPage(),
              settings: RouteSettings(
                name: '/event/fortune',
                arguments: {
                  'fromDeepLink': true,
                  'inviter': inviterOrCode,
                  'raw': uri.toString(),
                  'me': me,
                },
              ),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _deepLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// ─────────────────────────────────────────────────────────
/// ✅ 전역 스크롤 동작: Glow 제거 + 바운스 유지
/// - buildOverscrollIndicator: glow(민트빛) 완전 제거
/// - getScrollPhysics: 모든 플랫폼에서 iOS식 바운스 적용
/// ─────────────────────────────────────────────────────────
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // glow 효과 제거 (거의 안 보이는 색 대신 완전 제거)
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // iOS식 바운스 유지. 항상 스크롤 가능하도록 AlwaysScrollable 추가.
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

/// 가로 배치 확정 Confirm 다이얼로그 (전역 ElevatedTheme 영향 무시)
Future<bool?> showConfirmDialogHorizontal(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = '취소',
  String okText = '삭제',
  bool destructive = true, // 빨간/주의 액션이면 true
}) {
  // 모달 안에서만 쓸 컴팩트 버튼 스타일 (전역 최소높이/풀폭 무시)
  final compactElevated = ElevatedButton.styleFrom(
    elevation: 0,
    minimumSize: const Size(0, 40), // 높이만 보장, 너비는 내용만큼
    padding: const EdgeInsets.symmetric(horizontal: 16),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    backgroundColor: destructive ? Colors.red : primaryColor,
    foregroundColor: Colors.white,
  );
  final compactText = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    foregroundColor: Colors.black,
  );

  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      // 모양 옵션(필요 없으면 제거해도 됨)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Row(
        children: const [
          Icon(Icons.delete_outline, size: 20),
          SizedBox(width: 6),
          Text('리뷰 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      content: Text(message),
      // ⬇️ 핵심: actions에 Row 하나만 넣어서 가로 고정
      actions: [
        SizedBox(
          width: double.infinity, // 오른쪽 정렬용
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: compactText,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: compactElevated,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(okText),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
