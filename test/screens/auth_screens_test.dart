import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/screens/login.dart';
import 'package:watch_verse/screens/register.dart';
import 'package:watch_verse/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('LoginScreen validation', () {
    testWidgets('shows email/password errors when submitted empty',
        (tester) async {
      await tester.pumpWidget(
        _wrap(LoginScreen(auth: MockFirebaseAuth())),
      );

      await tester.tap(find.text('Log In'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('rejects an email missing an @', (tester) async {
      await tester.pumpWidget(
        _wrap(LoginScreen(auth: MockFirebaseAuth())),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'),
          'not-an-email');
      await tester.tap(find.text('Log In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });
  });

  group('RegisterScreen validation', () {
    testWidgets('shows field errors when submitted empty', (tester) async {
      await tester.pumpWidget(
        _wrap(RegisterScreen(auth: MockFirebaseAuth())),
      );

      // The form scrolls; at the 800x600 test window it's a readable-width
      // column, so the button can sit below the fold.
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Please enter a username'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('rejects a too-short password', (tester) async {
      await tester.pumpWidget(
        _wrap(RegisterScreen(auth: MockFirebaseAuth())),
      );

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Username'), 'someone');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'someone@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm password'), '123');
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('At least 6 characters'), findsOneWidget);
    });

    testWidgets('rejects mismatched passwords', (tester) async {
      await tester.pumpWidget(
        _wrap(RegisterScreen(auth: MockFirebaseAuth())),
      );

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Username'), 'someone');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'someone@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm password'),
          'password2');
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
