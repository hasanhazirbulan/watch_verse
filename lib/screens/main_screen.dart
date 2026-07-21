import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:watch_verse/screens/home_screen.dart';
import 'package:watch_verse/screens/up_next_screen.dart';
import 'package:watch_verse/screens/watchlist_screen.dart';
import 'package:watch_verse/screens/profile_screen.dart';
import 'package:watch_verse/screens/search_screen.dart';
import 'package:watch_verse/theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // One Navigator per tab so detail pages push *inside* the tab — the bottom
  // navigation bar stays visible instead of being covered by a full-screen
  // route. Each tab also keeps its own back stack.
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const List<Widget> _rootScreens = [
    HomeScreen(),
    UpNextScreen(),
    WatchlistScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  Widget _tabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => _rootScreens[index]),
    );
  }

  void _onTap(int index) {
    if (index == _selectedIndex) {
      // Re-tapping the current tab returns it to its root.
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  void _handleBack() {
    final nav = _navigatorKeys[_selectedIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    } else {
      SystemNavigator.pop(); // at Home root → leave the app
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(5, _tabNavigator),
        ),
        bottomNavigationBar: CurvedNavigationBar(
          backgroundColor: Colors.transparent,
          color: context.colors.surface,
          buttonBackgroundColor: context.colors.primary,
          height: 62,
          animationDuration: const Duration(milliseconds: 300),
          index: _selectedIndex,
          items: const [
            Icon(Icons.home_rounded, size: 28, color: Colors.white),
            Icon(Icons.live_tv_rounded, size: 26, color: Colors.white),
            Icon(Icons.movie_rounded, size: 26, color: Colors.white),
            Icon(Icons.search_rounded, size: 28, color: Colors.white),
            Icon(Icons.person_rounded, size: 28, color: Colors.white),
          ],
          onTap: _onTap,
        ),
      ),
    );
  }
}
