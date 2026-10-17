import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/main_screen.dart'; // MainScreen import
import 'package:watch_verse/screens/login.dart'; // LoginScreen import
import 'package:watch_verse/screens/splash_screen.dart'; // SplashScreen import
import 'package:watch_verse/screens/settings_screen.dart';
import 'package:watch_verse/screens/profile_screen.dart';
import 'package:watch_verse/services/notification_service.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'firebase_options.dart'; // Firebase configuration import

/// Lets [NotificationService] push a route when a notification is tapped,
/// without needing a BuildContext at the point the tap arrives (which can be
/// before any screen has built, e.g. a cold start from a notification).
final navigatorKey = GlobalKey<NavigatorState>();

/// Screen-view + default-event tracking. `navigatorObservers` picks this up
/// in [MyApp]. Screens pushed without an explicit `RouteSettings.name` (most
/// of this app's `Navigator.push(MaterialPageRoute(...))` calls) show up as
/// unnamed in Analytics — session/first-open/app-update events still fire
/// regardless, this only affects per-screen breakdowns.
final analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // No-ops until REVENUECAT_API_KEY_IOS is set (see secrets.example.json) —
  // every Pro gate just stays locked until then.
  await ProService.instance.initialize();

  // Crash/error reporting. Disabled in debug builds (kDebugMode) so local
  // development noise never lands in the Crashlytics console — TestFlight
  // and App Store builds are release/profile, so they're unaffected.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // No runZonedGuarded: PlatformDispatcher.onError above already catches
  // uncaught async errors, and wrapping only runApp in a new zone made it run
  // in a different zone than ensureInitialized (Flutter's "Zone mismatch").
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // WatchVerse is dark-only by design: poster art and backdrops carry the
    // whole interface, and they read very differently against a light
    // background. `theme` is set to the dark ThemeData as well as `darkTheme`
    // so the platform's light mode can never pull a light palette through.
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],
      debugShowCheckedModeBanner: false,
      title: 'WatchVerse',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // English everywhere, whatever the device language: TMDB content
      // (titles, plots, genres, game pools) is English, so a Turkish UI
      // around it read as a half-translated app. app_tr.arb is kept so this
      // is a one-line switch if Turkish ever comes back.
      locale: const Locale('en'),
      // Insets every screen from side safe areas (landscape notch, the side
      // status bar on the iPhone Duo's inner display) in one place.
      builder: (context, child) =>
          SideSafeArea(color: AppColors.dark.background, child: child!),
      home: const SplashWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    // Show the splash briefly, then hand off to the auth router.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return; // guard against the "unmounted State" crash
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // Display SplashScreen
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Listen for auth state changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading indicator while checking auth state
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData) {
          // Fire-and-forget: request push permission and register the FCM
          // token for this user. Failures are swallowed inside the service
          // so they never block sign-in.
          NotificationService.instance
              .initialize(snapshot.data!.uid, navigatorKey: navigatorKey);
          // Navigate to MainScreen if authenticated
          return const MainScreen();
        } else {
          // Navigate to LoginScreen if not authenticated
          return const LoginScreen();
        }
      },
    );
  }
}
