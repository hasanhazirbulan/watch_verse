import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Widget _list(Stream<List<String>> stream, {List<String>? initialData}) =>
    StreamListView<String>(
      stream: stream,
      initialData: initialData,
      emptyBuilder: (_) => const Text('empty'),
      builder: (_, items) => Text(items.join(',')),
    );

void main() {
  testWidgets('StreamListView shows a spinner while waiting with no data',
      (tester) async {
    final ctrl = StreamController<List<String>>();
    addTearDown(ctrl.close);
    await tester.pumpWidget(_wrap(_list(ctrl.stream)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('StreamListView renders initialData without a spinner',
      (tester) async {
    final ctrl = StreamController<List<String>>.broadcast();
    addTearDown(ctrl.close);
    await tester.pumpWidget(_wrap(_list(ctrl.stream, initialData: ['a'])));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('a'), findsOneWidget);

    ctrl.add(['a', 'b']);
    await tester.pump();
    expect(find.text('a,b'), findsOneWidget);
  });

  testWidgets('StreamListView keeps its subscription when given the same stream',
      (tester) async {
    var listens = 0;
    final ctrl = StreamController<List<String>>.broadcast(
        onListen: () => listens++);
    addTearDown(ctrl.close);
    final stream = ctrl.stream;
    await tester.pumpWidget(_wrap(_list(stream)));
    ctrl.add(['x']);
    await tester.pump();
    await tester.pumpWidget(_wrap(_list(stream)));
    expect(find.text('x'), findsOneWidget);
    expect(listens, 1);
  });

  testWidgets('formatTmdbDate formats valid dates and keeps the raw fallback',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_wrap(Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    })));
    expect(formatTmdbDate(ctx, '2026-10-13'), 'Oct 13, 2026');
    expect(formatTmdbDate(ctx, '2026'), '2026');
    expect(formatTmdbDate(ctx, 'garbage'), 'garbage');
  });
}
