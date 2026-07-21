import 'package:flutter/material.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/movie_detail_screen.dart';
import 'package:watch_verse/screens/tv_detail_screen.dart';

/// Routes a [MediaItem] to the correct detail screen based on its type.
/// Centralized so every card/tile behaves identically.
void openMedia(BuildContext context, MediaItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => item.mediaType == MediaType.tv
          ? TvDetailScreen(seed: item)
          : MovieDetailsScreen(movie: item.toMovie()),
    ),
  );
}
