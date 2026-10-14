import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/person_screen.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/streaming/streaming_logic.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/streaming_widgets.dart';

/// Horizontal strip of top-billed cast; tapping a face opens their filmography.
class CastStrip extends StatelessWidget {
  final List<CastMember> cast;
  const CastStrip({super.key, required this.cast});

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(AppLocalizations.of(context)!.detailCastTitle,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length.clamp(0, 20),
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _castTile(context, cast[i]),
          ),
        ),
      ],
    );
  }

  Widget _castTile(BuildContext context, CastMember m) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PersonScreen(personId: m.id, name: m.name)),
      ),
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            // TmdbImage (not a bare NetworkImage) so a dead/slow profile
            // photo falls back to the person icon instead of an empty circle
            // plus an uncaught image-load exception.
            ClipOval(
              child: SizedBox(
                width: 76,
                height: 76,
                child: TmdbImage(
                  url: Tmdb.poster(m.profilePath, size: 'w185'),
                  placeholderIcon: Icons.person,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            if (m.character.isNotEmpty)
              Text(m.character,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// A titled horizontal rail of poster cards (recommendations, filmography, …).
class MediaRail extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  const MediaRail({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                PosterCard(item: items[i], width: 120),
          ),
        ),
      ],
    );
  }
}

/// "Where to Watch" — streaming provider logos for the viewer's region
/// (JustWatch data via TMDB, credited underneath as TMDB requires). The
/// user's own services ([myProviderIds], from Settings → My streaming
/// services) are moved first, ringed, and called out ("On your Netflix").
/// Renders nothing when no providers are listed.
class WatchProvidersSection extends StatelessWidget {
  final List<WatchProvider> providers;
  final Set<int> myProviderIds;
  const WatchProvidersSection(
      {super.key, required this.providers, this.myProviderIds = const {}});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final ordered = userServicesFirst(providers, myProviderIds);
    final mine = matchUserServices(providers, myProviderIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.detailWhereToWatch,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: context.colors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l10n.streamingOnYour(joinProviderNames(mine)),
                    style: TextStyle(
                        color: context.colors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ordered
              .map((p) => _logo(context, p, myProviderIds.contains(p.id)))
              .toList(),
        ),
        const SizedBox(height: 6),
        const JustWatchCredit(),
      ],
    );
  }

  Widget _logo(BuildContext context, WatchProvider p, bool mine) {
    // A failed logo load shows a letter tile (see ProviderLogo), not
    // Flutter's broken-image glyph.
    final logo = ProviderLogo(provider: p);
    return Tooltip(
      message: p.name,
      child: mine
          ? Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.success, width: 2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: logo,
            )
          : logo,
    );
  }
}

/// Read-only community reviews from TMDB.
class ReviewsSection extends StatelessWidget {
  final List<Review> reviews;
  const ReviewsSection({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final shown = reviews.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.detailReviewsTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text(l10n.detailReviewsSubtitle,
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        ...shown.map((r) => _ReviewCard(review: r)),
      ],
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: context.colors.surfaceAlt,
                child: Text(
                  r.author.isNotEmpty ? r.author[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (r.rating != null)
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: context.colors.accent, size: 16),
                    const SizedBox(width: 2),
                    Text(r.rating!.toStringAsFixed(0),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.content,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
                color: context.colors.textSecondary, height: 1.4, fontSize: 13),
          ),
          if (r.content.length > 220)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    _expanded
                        ? AppLocalizations.of(context)!.detailShowLess
                        : AppLocalizations.of(context)!.detailReadMore,
                    style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A "Watch Trailer" pill that self-fetches the YouTube key and opens it
/// externally. Renders nothing when no trailer exists.
class TrailerButton extends StatefulWidget {
  final MediaType type;
  final int id;
  const TrailerButton({super.key, required this.type, required this.id});

  @override
  State<TrailerButton> createState() => _TrailerButtonState();
}

class _TrailerButtonState extends State<TrailerButton> {
  String? _key;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    APIservices().getTrailerKey(widget.type, widget.id).then((k) {
      if (!mounted) return;
      setState(() {
        _key = k;
        _loaded = true;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    });
  }

  Future<void> _open() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$_key');
    bool ok;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // launchUrl throws (PlatformException) rather than returning false
      // when no app can handle the URL on some platforms.
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.detailCouldNotOpenTrailer)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _key == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
            side: BorderSide(color: context.colors.primary, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _open,
          icon: Icon(Icons.play_circle_fill_rounded,
              color: context.colors.primary),
          label: Text(AppLocalizations.of(context)!.detailWatchTrailer,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
