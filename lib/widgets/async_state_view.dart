import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// Centered spinner shown while a [Stream]/[Future] hasn't resolved yet.
Widget asyncLoadingIndicator() =>
    const Center(child: CircularProgressIndicator());

/// Centered error message shown when a [Stream]/[Future] fails. Screens were
/// previously not checking `hasError` at all, so failures (e.g. a TMDB call
/// with no API key configured) silently rendered as an infinite spinner or
/// an empty state instead of telling the user anything went wrong.
Widget asyncErrorView(BuildContext context, Object error) {
  final colors = context.colors;
  final l10n = AppLocalizations.of(context)!;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(l10n.asyncErrorMessage(error.toString()),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    ),
  );
}

/// Consistent loading/error/empty handling for the list-shaped Firestore
/// streams used across screens (watchlist, history, lists, tracked shows…).
class StreamListView<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final WidgetBuilder emptyBuilder;

  const StreamListView({
    super.key,
    required this.stream,
    required this.builder,
    required this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return asyncLoadingIndicator();
        }
        if (snapshot.hasError) {
          return asyncErrorView(context, snapshot.error!);
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return emptyBuilder(context);
        return builder(context, items);
      },
    );
  }
}

/// Same idea for one-shot list-shaped Futures (TMDB fetches, resolved user
/// lists, etc).
class FutureListView<T> extends StatelessWidget {
  final Future<List<T>> future;
  final Widget Function(BuildContext context, List<T> items) builder;
  final WidgetBuilder emptyBuilder;

  const FutureListView({
    super.key,
    required this.future,
    required this.builder,
    required this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return asyncLoadingIndicator();
        }
        if (snapshot.hasError) {
          return asyncErrorView(context, snapshot.error!);
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return emptyBuilder(context);
        return builder(context, items);
      },
    );
  }
}

/// Same idea for a single-value one-shot Future (e.g. one detail object).
class FutureValueView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T value) builder;

  const FutureValueView({
    super.key,
    required this.future,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return asyncLoadingIndicator();
        }
        if (snapshot.hasError) {
          return asyncErrorView(context, snapshot.error!);
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}
