// lib/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:reframe/event/pages/start_page.dart';
import 'package:reframe/pages/customer/more_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/home_page.dart';
import '../constants/color.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  Widget _rootForIndex(int i) => switch (i) {
    0 => const HomePage(),
    1 => DepositMainPage(),

    2 => const StartPage(),

    3 => const MorePage(),
    _ => const HomePage(),
  };

  Widget _buildTabNavigator(int index) {
    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => _rootForIndex(index),
          settings: settings,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_selectedIndex].currentState!;
    if (nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  void _onTapNav(int index) {
    if (_selectedIndex == index) {
      final nav = _navigatorKeys[index].currentState!;
      if (nav.canPop()) nav.popUntil((r) => r.isFirst);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(

        backgroundColor: Colors.white, // ✅ 전체 배경 흰색
        extendBody: false,

        body: Stack(
          children: [
            _buildTabNavigator(0),
            _buildTabNavigator(1),
            _buildTabNavigator(2),
            _buildTabNavigator(3),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          bottom: true,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: _AttachedBankBar(
              selectedIndex: _selectedIndex,
              onTap: _onTapNav,
            ),
          ),
        ),
      ),
    );
  }
}


/// 하단에 붙고 좌우 꽉 차며 '위쪽'만 둥근 스타일 + 상단 보더라인
class _AttachedBankBar extends StatelessWidget {
  const _AttachedBankBar({

    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const Color _bg = Colors.white;
  static const Color _selected = Color(0xFF222B38);
  static const Color _unselected = Color(0xFFB5BEC8);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final bool compact = c.maxWidth < 360;
        final double vPad = compact ? 8 : 10;
        final double hPad = compact ? 8 : 12;


        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            color: _bg,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavCol(
                  index: 0,
                  label: '홈',
                  icon: Icons.home_filled,
                  selectedIndex: selectedIndex,
                  onTap: onTap,
                  compact: compact,
                  selectedColor: _selected,
                  unselectedColor: _unselected,
                ),
                _NavCol(
                  index: 1,
                  label: '상품',
                  icon: Icons.shopping_bag_outlined,
                  selectedIndex: selectedIndex,
                  onTap: onTap,
                  compact: compact,
                  selectedColor: _selected,
                  unselectedColor: _unselected,
                ),
                _NavCol(
                  index: 2,
                  label: '이벤트',
                  icon: Icons.card_giftcard_outlined,
                  selectedIndex: selectedIndex,
                  onTap: onTap,
                  compact: compact,
                  selectedColor: _selected,
                  unselectedColor: _unselected,
                ),
                _NavCol(
                  index: 3,
                  label: '더보기',
                  icon: Icons.menu_rounded,
                  selectedIndex: selectedIndex,
                  onTap: onTap,
                  compact: compact,
                  selectedColor: _selected,
                  unselectedColor: _unselected,
                ),
              ],

        return Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),

            ),
            // ✅ 그림자 제거, 대신 보더라인 추가
            border: Border(
              top: BorderSide(color: Colors.grey.shade300, width: 0.6),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavCol(
                index: 0,
                label: '홈',
                icon: Icons.home_filled,
                selectedIndex: selectedIndex,
                onTap: onTap,
                compact: compact,
                selectedColor: _selected,
                unselectedColor: _unselected,
              ),
              _NavCol(
                index: 1,
                label: '상품',
                icon: Icons.shopping_bag_outlined,
                selectedIndex: selectedIndex,
                onTap: onTap,
                compact: compact,
                selectedColor: _selected,
                unselectedColor: _unselected,
              ),
              _NavCol(
                index: 2,
                label: '이벤트',
                icon: Icons.card_giftcard_outlined,
                selectedIndex: selectedIndex,
                onTap: onTap,
                compact: compact,
                selectedColor: _selected,
                unselectedColor: _unselected,
              ),
              _NavCol(
                index: 3,
                label: '더보기',
                icon: Icons.menu_rounded,
                selectedIndex: selectedIndex,
                onTap: onTap,
                compact: compact,
                selectedColor: _selected,
                unselectedColor: _unselected,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavCol extends StatelessWidget {
  const _NavCol({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIndex,
    required this.onTap,
    required this.compact,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final int index;
  final String label;
  final IconData icon;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool compact;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final bool selected = index == selectedIndex;
    final Color color = selected ? selectedColor : unselectedColor;
    final double iconSize = compact ? 24 : 26;
    final double fontSize = compact ? 11.5 : 12.5;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.0,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
