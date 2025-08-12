import 'package:flutter/material.dart';
import 'package:reframe/pages/customer/more_page.dart';
import 'package:reframe/pages/deposit/deposit_list_page.dart';
import 'package:reframe/pages/deposit/deposit_main_page.dart';
import 'package:reframe/pages/home_page.dart';

import '../constants/color.dart';
import '../pages/savings_test/screens/start_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _selectedIndex = 0;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SafeArea(child: HomePage()),
          SafeArea(child: DepositMainPage()),
          SafeArea(child: StartScreen()),
          SafeArea(child: MorePage())
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "홈"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.savings),
              label: "상품"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.event),
              label: "이벤트"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: "전체"
          )
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        unselectedItemColor: Colors.black38,
        selectedItemColor: Colors.black,
      ),
    );
  }
}
