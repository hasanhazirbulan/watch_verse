import 'dart:async';
import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/social_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

/// What the search field is currently scoped to. Titles (movies + shows) is the
/// default; "People" flips the same field into a user search (Letterboxd-style
/// filter chips), so Find Friends now lives here instead of the Profile tab.
enum _Filter { all, movies, tv, people }

extension on _Filter {
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case _Filter.all:
        return l10n.searchFilterAll;
      case _Filter.movies:
        return l10n.searchFilterMovies;
      case _Filter.tv:
        return l10n.searchFilterTv;
      case _Filter.people:
        return l10n.searchFilterPeople;
    }
  }

  bool get isPeople => this == _Filter.people;
}

class SearchScreen extends StatefulWidget {
  final bool initialPeople;
  const SearchScreen({super.key, this.initialPeople = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final APIservices _api = APIservices();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  late _Filter _filter =
      widget.initialPeople ? _Filter.people : _Filter.all;

  // Cached raw results per scope + the query they belong to, so toggling
  // Movies/TV/All never triggers a refetch (client-side filter instead).
  List<MediaItem> _titlesRaw = [];
  List<Map<String, dynamic>> _people = [];
  String _titlesQuery = '';
  String _peopleQuery = '';

  bool _loading = false;
  String _query = '';

  void _onChanged(String value) {
    _debounce?.cancel();
    _query = value;
    _runId++; // the query changed: drop any search still in flight
    if (value.trim().isEmpty) {
      setState(() {
        _titlesRaw = [];
        _people = [];
        _titlesQuery = '';
        _peopleQuery = '';
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _run);
  }

  void _setFilter(_Filter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    if (_query.trim().isNotEmpty) _run();
  }

  // Bumped on every search; a response is only applied if no newer search
  // (or a clear) started while it was in flight. Without this, typing
  // "bat" → "batman" could let the slower "bat" response land last and
  // show its results under the "batman" query.
  int _runId = 0;

  Future<void> _run() async {
    final q = _query.trim();
    if (q.isEmpty) return;
    final runId = ++_runId;
    final people = _filter.isPeople;
    setState(() => _loading = true);
    try {
      if (people) {
        if (_peopleQuery != q) {
          final found = await SocialService.instance.searchUsers(q);
          if (runId != _runId) return;
          _people = found;
          _peopleQuery = q;
        }
      } else if (_titlesQuery != q) {
        final found = await _api.searchMulti(q);
        if (runId != _runId) return;
        _titlesRaw = found;
        _titlesQuery = q;
      }
    } catch (e) {
      if (!mounted || runId != _runId) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchFailed(e.toString()))),
      );
    }
    if (!mounted || runId != _runId) return;
    setState(() => _loading = false);
  }

  List<MediaItem> get _visibleTitles {
    switch (_filter) {
      case _Filter.movies:
        return _titlesRaw
            .where((i) => i.mediaType == MediaType.movie)
            .toList();
      case _Filter.tv:
        return _titlesRaw.where((i) => i.mediaType == MediaType.tv).toList();
      default:
        return _titlesRaw;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _filter.isPeople
                    ? l10n.searchHintPeople
                    : l10n.searchHintTitles,
                prefixIcon: Icon(
                    _filter.isPeople
                        ? Icons.person_search_rounded
                        : Icons.search_rounded,
                    color: context.colors.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onChanged,
            ),
          ),
          _filterChips(),
          const SizedBox(height: 4),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _Filter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _Filter.values[i];
          final active = f == _filter;
          return GestureDetector(
            onTap: () => _setFilter(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: active ? context.colors.brandGradient : null,
                color: active ? null : context.colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: active
                    ? null
                    : Border.all(color: Colors.white12, width: 1),
              ),
              child: Text(
                f.label(context),
                style: TextStyle(
                  color: active ? Colors.white : context.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_query.trim().isEmpty) {
      return _emptyState(
        context,
        _filter.isPeople ? Icons.group_outlined : Icons.search_rounded,
        _filter.isPeople
            ? l10n.searchFindFriendsTitle
            : l10n.searchFindNextWatchTitle,
        _filter.isPeople
            ? l10n.searchFindFriendsSubtitle
            : l10n.searchFindNextWatchSubtitle,
      );
    }

    if (_filter.isPeople) {
      if (_people.isEmpty) {
        return _emptyState(
            context,
            Icons.sentiment_dissatisfied_rounded,
            l10n.searchNoOneFoundTitle,
            l10n.searchNoUsersMatched(_query));
      }
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: _people.length,
        itemBuilder: (context, i) => UserTile(user: _people[i]),
      );
    }

    final titles = _visibleTitles;
    if (titles.isEmpty) {
      return _emptyState(context, Icons.sentiment_dissatisfied_rounded,
          l10n.searchNoResultsTitle, l10n.searchNothingMatched(_query));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: titles.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
      itemBuilder: (context, index) => _resultTile(context, titles[index]),
    );
  }

  Widget _resultTile(BuildContext context, MediaItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 84,
          child: TmdbImage(url: Tmdb.poster(item.posterPath, size: 'w185')),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            MediaTypeChip(type: item.mediaType),
            const SizedBox(width: 8),
            if (item.year.isNotEmpty)
              Text(item.year,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 12)),
            const Spacer(),
            RatingBadge(rating: item.voteAverage, compact: true),
          ],
        ),
      ),
      onTap: () => openMedia(context, item),
    );
  }

  Widget _emptyState(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
