import 'dart:ui'; // needed for ImageFilter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Purely visual splash. Navigation is owned by [SplashWrapper] in main.dart, so
/// this widget must NOT navigate itself (doing so caused a double-navigation
/// race and an "unmounted State" crash).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/thebear.jpg'), // background image
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          // Blur effect
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.6), // dark overlay over the blur
            child: Center(
              child: Image.asset(
                'assets/images/logoW.png', // logo image
                width: 200, // logo width
                height: 200, // logo height
              ),
            ),
          ),
        ),
      ),
    );
  }
}
