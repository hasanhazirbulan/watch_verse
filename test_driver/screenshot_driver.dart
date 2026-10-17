// Host-side driver for integration_test/app_store_screenshots_test.dart:
// writes every `binding.takeScreenshot(name)` the test makes to
// $SCREENSHOT_DIR/<name>.png (default build/screenshots/<SCREENSHOT_DEVICE
// or "device">). See tool/app_store_screenshots.sh for the full run
// (status-bar override, simulator capture, alpha removal).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final env = Platform.environment;
  final dir = Directory(env['SCREENSHOT_DIR'] ??
      'build/screenshots/${env['SCREENSHOT_DEVICE'] ?? 'device'}');
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await dir.create(recursive: true);
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(bytes);
      stdout.writeln('screenshot saved: ${file.path}');
      return true;
    },
  );
}
