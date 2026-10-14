import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/streaming/streaming_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// TMDB's terms require crediting JustWatch wherever provider data is shown.
class JustWatchCredit extends StatelessWidget {
  final TextAlign textAlign;
  const JustWatchCredit({super.key, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.of(context)!.streamingJustWatchCredit,
    textAlign: textAlign,
    style: TextStyle(color: context.colors.textMuted, fontSize: 11),
  );
}

/// Square provider logo with a letter-tile fallback (no logo / failed load).
class ProviderLogo extends StatelessWidget {
  final WatchProvider provider;
  final double size;
  final double radius;
  const ProviderLogo({
    super.key,
    required this.provider,
    this.size = 38,
    this.radius = 9,
  });

  @override
  Widget build(BuildContext context) {
    final url = Tmdb.logo(provider.logoPath);
    final fallback = Container(
      color: context.colors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        provider.name.isNotEmpty ? provider.name[0] : '?',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.34),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Small logo badge for a poster corner: the first of the user's services a
/// title is streaming on.
class StreamingBadge extends StatelessWidget {
  final List<WatchProvider> providers;
  const StreamingBadge({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: providers.map((p) => p.name).join(', '),
      child: Container(
        key: const ValueKey('streaming-badge'),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ProviderLogo(provider: providers.first, size: 20, radius: 5),
      ),
    );
  }
}

/// Pill filter chip in the app's style (same look as Up Next's filters).
class StreamingFilterChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const StreamingFilterChip({
    super.key,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: active ? context.colors.brandGradient : null,
            color: active ? null : context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: active
                ? null
                : Border.all(color: context.colors.surfaceAlt, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.live_tv_rounded,
                size: 16,
                color: active ? Colors.white : context.colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.streamingFilterChip,
                style: TextStyle(
                  color: active ? Colors.white : context.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a list of library items with the "On my services" behaviour:
///  * filter off — renders every item; badges only for titles whose
///    availability is already cached (no network);
///  * filter on — checks every item (cache first, then TMDB with bounded
///    concurrency), shows "Checking 12/80…" progress and a retry for
///    failures, and renders only the items streaming on the user's services.
class StreamingFilterView<T> extends StatefulWidget {
  final List<T> items;
  final TitleRef Function(T item) refOf;
  final bool active;
  final StreamingPrefs prefs;
  final String region;
  final AvailabilityChecker checker;
  final VoidCallback onSetUp;

  /// Builds the list for [visible] items; [matchesOf] gives the user's
  /// services each item is streaming on (empty when unknown/none).
  final Widget Function(
    BuildContext context,
    List<T> visible,
    List<WatchProvider> Function(T item) matchesOf,
  )
  builder;

  const StreamingFilterView({
    super.key,
    required this.items,
    required this.refOf,
    required this.active,
    required this.prefs,
    required this.region,
    required this.checker,
    required this.onSetUp,
    required this.builder,
  });

  @override
  State<StreamingFilterView<T>> createState() => _StreamingFilterViewState<T>();
}

class _StreamingFilterViewState<T> extends State<StreamingFilterView<T>> {
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant StreamingFilterView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleCheck();
  }

  List<TitleRef> get _refs => widget.items.map(widget.refOf).toList();

  void _scheduleCheck() {
    if (!widget.prefs.isConfigured) return;
    final refs = _refs;
    final signature =
        '${widget.region}|${widget.active}|'
        '${refs.map((r) => r.keyFor('')).join(',')}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    // Post-frame: check() notifies listeners, which must not happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.checker.check(refs, widget.region, fetch: widget.active);
    });
  }

  List<WatchProvider> _matchesOf(T item) {
    final available = widget.checker.availabilityFor(widget.refOf(item));
    if (available == null) return const [];
    return matchUserServices(available, widget.prefs.providerIds);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.prefs.isConfigured) {
      return widget.active
          ? _notSetUp(context)
          : widget.builder(context, widget.items, (_) => const []);
    }
    return ListenableBuilder(
      listenable: widget.checker,
      builder: (context, _) {
        if (!widget.active) {
          return widget.builder(context, widget.items, _matchesOf);
        }
        final visible = widget.items
            .where((i) => _matchesOf(i).isNotEmpty)
            .toList();
        final checker = widget.checker;
        final running =
            checker.isRunning || checker.checked < widget.items.length;
        return Column(
          children: [
            _statusRow(context, running),
            Expanded(
              child: visible.isEmpty
                  ? (running
                        ? const SizedBox.shrink()
                        : _message(
                            context,
                            Icons.tv_off_rounded,
                            AppLocalizations.of(context)!.streamingFilterEmpty,
                          ))
                  : widget.builder(context, visible, _matchesOf),
            ),
          ],
        );
      },
    );
  }

  Widget _statusRow(BuildContext context, bool running) {
    final l10n = AppLocalizations.of(context)!;
    final checker = widget.checker;
    final total = widget.items.length;
    final checked = checker.checked.clamp(0, total);
    final failed = checker.failedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: running
                    ? Text(
                        l10n.streamingChecking(checked, total),
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    : failed > 0
                    ? Text(
                        l10n.streamingCheckFailed(failed),
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (!running && failed > 0)
                TextButton(
                  onPressed: checker.retryFailed,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(l10n.retryAction),
                ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total == 0 ? null : checked / total,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          const SizedBox(height: 4),
          const JustWatchCredit(textAlign: TextAlign.end),
        ],
      ),
    );
  }

  Widget _notSetUp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv_rounded,
              size: 52,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.streamingNotSetUpTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.streamingNotSetUpBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: widget.onSetUp,
              child: Text(l10n.streamingSetUpAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
