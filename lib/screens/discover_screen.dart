import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/responsive.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/quick_add_sheet.dart';

/// Browse a single genre (movies or TV). Lazily loads more pages as the user
/// scrolls toward the bottom.
class DiscoverScreen extends StatefulWidget {
  final MediaType type;
  final Genre genre;
  const DiscoverScreen({super.key, required this.type, required this.genre});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final APIservices _api = APIservices();
  final ScrollController _scroll = ScrollController();

  final List<MediaItem> _items = [];
  final Set<String> _seen = {};
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _error = false;

  /// Bumped by [_refresh]; a page that resolves under an older generation is
  /// dropped so a refresh mid-load can't mix old and new pages.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Defer the first load until after the first frame so the initial
    // setState() never runs during build (which would blank the screen).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // After a failed page, wait for the explicit retry in the footer rather
    // than re-firing on every scroll tick.
    if (!_error &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !mounted) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final batch =
          await _api.discoverByGenre(widget.type, widget.genre.id, page: _page);
      if (!mounted || gen != _generation) return;
      setState(() {
        for (final m in batch) {
          if (_seen.add('${m.mediaType}-${m.id}')) _items.add(m);
        }
        _page++;
        _hasMore = batch.isNotEmpty && _page <= 500;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted || gen != _generation) return;
      // Keep _hasMore so the footer can offer a retry (it used to silently
      // stop paging with no message).
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _generation++;
      _loading = false; // any in-flight page is now stale and will be dropped
      _items.clear();
      _seen.clear();
      _page = 1;
      _hasMore = true;
      _error = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genre.name),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: context.colors.primary,
        backgroundColor: context.colors.surfaceAlt,
        onRefresh: _refresh,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_items.isEmpty && _loading) {
      return ListView(
        children: const [
          SizedBox(height: 16),
          RailSkeleton(height: 220, itemWidth: 110),
          SizedBox(height: 20),
          RailSkeleton(height: 220, itemWidth: 110),
        ],
      );
    }
    if (_items.isEmpty && _error) {
      return _message(Icons.wifi_off_rounded, l10n.discoverLoadErrorTitle,
          l10n.discoverLoadErrorSubtitle);
    }
    if (_items.isEmpty) {
      return _message(Icons.sentiment_dissatisfied_rounded,
          l10n.discoverEmptyTitle,
          l10n.discoverEmptySubtitle(widget.genre.name));
    }

    final failedMore = _error && _hasMore;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, failedMore ? 0 : 90),
          sliver: SliverGrid(
            // 3 columns on phones, more on wide windows.
            gridDelegate: const SliverGridDelegateWithAdaptiveCount(
              compactCount: 3,
              mainAxisSpacing: 18,
              crossAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= _items.length) {
                  return const SkeletonBox(height: 160, radius: 14);
                }
                return PosterCard(
                  item: _items[i],
                  width: double.infinity,
                  onTap: () => openMedia(context, _items[i]),
                  onLongPress: () => showQuickAddSheet(context, _items[i]),
                  showProviderBadge: true,
                );
              },
              // +1 row-ish for the trailing loader.
              childCount: _items.length + (_hasMore && !failedMore ? 3 : 0),
            ),
          ),
        ),
        if (failedMore)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(l10n.discoverLoadMoreFailed,
                        style: TextStyle(color: context.colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _loadMore,
                    child: Text(l10n.retryAction),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _message(IconData icon, String title, String subtitle) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: context.colors.textMuted),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary)),
      ],
    );
  }
}
