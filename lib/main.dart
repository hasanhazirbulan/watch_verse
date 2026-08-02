import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/main_screen.dart'; // MainScreen import
import 'package:watch_verse/screens/login.dart'; // LoginScreen import
import 'package:watch_verse/screens/splash_screen.dart'; // SplashScreen import
import 'package:watch_verse/screens/settings_screen.dart';
import 'package:watch_verse/screens/profile_screen.dart';
import 'package:watch_verse/services/notification_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'firebase_options.dart'; // Firebase configuration import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      debugShowCheckedModeBanner: false,
      title: 'WatchVerse',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  const SplashWrapper({Key? key}) : super(key: key);

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
  const AuthWrapper({Key? key}) : super(key: key);

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
          NotificationService.instance.initialize(snapshot.data!.uid);
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
