import 'package:url_launcher/url_launcher.dart';

/// Hosted legal pages (Firebase Hosting serves `docs/`, see `firebase.json`).
/// Referenced from Settings and the paywall sheet — Apple requires a working
/// link to both the Privacy Policy and the subscription Terms of Use
/// (EULA) to be reachable from inside the app (guideline 3.1.2).
class LegalLinks {
  LegalLinks._();

  static final privacyPolicy =
      Uri.parse('https://watchvers.web.app/privacy-policy.html');
  static final termsOfService =
      Uri.parse('https://watchvers.web.app/terms-of-service.html');

  static Future<void> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}