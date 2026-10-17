import 'dart:async';
import 'dart:ui'; // needed for ImageFilter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_verse/services/splash_backdrop_service.dart';
import 'package:watch_verse/utils/responsive.dart';

/// Purely visual splash. Navigation is owned by [SplashWrapper] in main.dart, so
/// this widget must NOT navigate itself (doing so caused a double-navigation
/// race and an "unmounted State" crash).
///
/// The background is a different poster every launch — see
/// [SplashBackdropService].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Future<ImageProvider> _backdrop =
      SplashBackdropService.instance.pickForLaunch();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Downloads posters for the *next* launches; never blocks this one.
    unawaited(SplashBackdropService.instance.refreshInBackground());
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
      backgroundColor: Colors.black,
      // Decorative only (no input), so it can run under a side status bar.
      body: FullBleed(child: _body()),
    );
  }

  Widget _body() {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<ImageProvider>(
          future: _backdrop,
          builder: (context, snap) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: snap.data == null
                ? const SizedBox.expand()
                : Image(
                    key: ValueKey(snap.data),
                    image: snap.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    // A corrupt cached file shouldn't leave a red error box.
                    errorBuilder: (_, _, _) => Image.asset(
                        SplashBackdropService.bundled.first,
                        fit: BoxFit.cover),
                  ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Image.asset(
                'assets/images/logoW.png',
                width: 200,
                height: 200,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
