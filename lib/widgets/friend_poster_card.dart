import 'package:flutter/material.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/quick_add_sheet.dart';
import 'package:watch_verse/widgets/social_widgets.dart';

/// Poster card for the home screen's "Your Friends Also Watched" slider —
/// like [PosterCard], but with the friend's avatar, name and rating
/// overlaid at the bottom (Letterboxd's "New from friends" row). Long-press
/// opens the same quick-add sheet as the other home-screen poster rails.
class FriendPosterCard extends StatelessWidget {
  final MediaItem item;
  final String friendName;
  final String friendPhoto;
  final double rating; // 0-5, 0 when the friend hasn't rated it
  final double width;
  const FriendPosterCard({
    super.key,
    required this.item,
    required this.friendName,
    required this.friendPhoto,
    required this.rating,
    this.width = 130,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openMedia(context, item),
      onLongPress: () => showQuickAddSheet(context, item),
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TmdbImage(url: Tmdb.poster(item.posterPath)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
                if (rating > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: UserRatingBadge(rating: rating, compact: true),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      UserAvatar(photoURL: friendPhoto, name: friendName, radius: 10),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          friendName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
