import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';

/// Network image with a branded placeholder and smooth fade-in. Used for every
/// poster/backdrop/still in the app so failures degrade gracefully.
class TmdbImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final IconData placeholderIcon;

  const TmdbImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.movie_creation_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null) return _placeholder(context);
    return Image.network(
      url!,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: context.colors.surfaceAlt,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.colors.surfaceAlt,
        child: Center(
          child: Icon(placeholderIcon, color: context.colors.textMuted, size: 34),
        ),
      );
}

/// Small "⭐ 8.4" pill shown on poster/backdrop corners.
class RatingBadge extends StatelessWidget {
  final double rating;
  final bool compact;
  const RatingBadge({super.key, required this.rating, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: context.colors.accent, size: 14),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "★ 4.5" pill for a user's own 0-5 rating — visually distinct from
/// [RatingBadge] (always TMDB's 0-10 community score) so the two scales are
/// never mistaken for each other.
class UserRatingBadge extends StatelessWidget {
  final double rating;
  final bool compact;
  const UserRatingBadge({super.key, required this.rating, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: context.colors.accent,
              size: compact ? 12 : 14),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Movie" / "TV" chip used on search + mixed lists.
class MediaTypeChip extends StatelessWidget {
  final MediaType type;
  const MediaTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTv = type == MediaType.tv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isTv ? context.colors.info : context.colors.primary)
            .withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTv ? Icons.live_tv_rounded : Icons.movie_rounded,
              size: 12,
              color: isTv ? context.colors.info : context.colors.primary),
          const SizedBox(width: 4),
          Text(
            isTv ? l10n.mediaTypeTv : l10n.mediaTypeMovie,
            style: TextStyle(
              color: isTv ? context.colors.info : context.colors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with a small gradient accent bar.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Vertical poster card (2:3) used in horizontal rails and grids.
class PosterCard extends StatelessWidget {
  final MediaItem item;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PosterCard({
    super.key,
    required this.item,
    this.width = 130,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => openMedia(context, item),
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flexible poster: fills whatever height the rail gives it, so the
            // card can never overflow regardless of the parent's constraints.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: TmdbImage(url: Tmdb.poster(item.posterPath)),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: RatingBadge(rating: item.voteAverage, compact: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.year.isNotEmpty)
              Text(
                item.year,
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Large 16:9 hero card used in the "spotlight" carousel at the top of Home.
class BackdropCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  const BackdropCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => openMedia(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TmdbImage(url: Tmdb.backdrop(item.backdropPath)),
            DecoratedBox(
              decoration: BoxDecoration(gradient: context.colors.posterScrim),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: RatingBadge(rating: item.voteAverage),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MediaTypeChip(type: item.mediaType),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill segmented control (e.g. Movies / TV Shows).
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: active ? context.colors.brandGradient : null,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        active ? Colors.white : context.colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A single pulsing placeholder block used while content loads. Self-animating,
/// so it can be dropped anywhere without a shared controller.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 0.35 + _c.value * 0.45,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder row of poster cards, matching the real rails so the
/// jump from loading → loaded is seamless.
class RailSkeleton extends StatelessWidget {
  final double height;
  final double itemWidth;
  final int count;
  const RailSkeleton({
    super.key,
    this.height = 220,
    this.itemWidth = 120,
    this.count = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, __) => SizedBox(
          width: itemWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(
                  width: itemWidth, height: itemWidth * 1.45, radius: 14),
              const SizedBox(height: 8),
              SkeletonBox(width: itemWidth * 0.85, height: 10, radius: 4),
              const SizedBox(height: 6),
              SkeletonBox(width: itemWidth * 0.5, height: 9, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim gradient progress bar for show/season completion.
class ProgressPill extends StatelessWidget {
  final double value; // 0..1
  final double height;
  const ProgressPill({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: context.colors.surfaceAlt),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration:
                  BoxDecoration(gradient: context.colors.brandGradient),
            ),
          ),
        ],
      ),
    );
  }
}
