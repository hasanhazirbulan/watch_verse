import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:watch_verse/screens/finish_deletion_screen.dart';
import 'package:watch_verse/screens/home_screen.dart';
import 'package:watch_verse/screens/up_next_screen.dart';
import 'package:watch_verse/screens/watchlist_screen.dart';
import 'package:watch_verse/screens/profile_screen.dart';
import 'package:watch_verse/screens/search_screen.dart';
import 'package:watch_verse/services/account_deletion_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // The nav bar's icons are a fixed white (readable against the colored
  // "bump" around the selected tab), so its resting background has to stay
  // a fixed dark tone too — tying it to context.colors.surface made it pure
  // white in light mode, hiding every unselected icon.
  static const _navBarColor = Color(0xFF15171E);

  int _selectedIndex = 0;

  /// Set when the profile carries a `deletionPending` marker from an
  /// interrupted account deletion — the app is replaced by
  /// [FinishDeletionScreen] so a half-purged account never shows up as a
  /// normal one with an empty library.
  bool _deletionPending = false;

  @override
  void initState() {
    super.initState();
    _checkPendingDeletion();
  }

  Future<void> _checkPendingDeletion() async {
    try {
      final pending =
          await AccountDeletionService.instance.hasPendingDeletion();
      if (pending && mounted) setState(() => _deletionPending = true);
    } catch (_) {
      // Offline or a transient read error — don't block the app on this
      // check; it runs again on the next launch/sign-in.
    }
  }

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
    if (_deletionPending) return const FinishDeletionScreen();
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
          color: _navBarColor,
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
