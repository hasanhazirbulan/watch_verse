import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';

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
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !mounted) return;
    setState(() => _loading = true);
    try {
      final batch =
          await _api.discoverByGenre(widget.type, widget.genre.id, page: _page);
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _hasMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
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

    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      // +1 row-ish for the trailing loader.
      itemCount: _items.length + (_hasMore ? 3 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const SkeletonBox(height: 160, radius: 14);
        }
        return PosterCard(
          item: _items[i],
          width: double.infinity,
          onTap: () => openMedia(context, _items[i]),
        );
      },
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
