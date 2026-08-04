import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/api_service.dart';
import 'package:watch_verse/services/poll_service.dart';
import 'package:watch_verse/services/tv_tracking_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/utils/navigation.dart';
import 'package:watch_verse/widgets/media_widgets.dart';
import 'package:watch_verse/widgets/poll_widgets.dart';

class EpisodeDetailScreen extends StatefulWidget {
  final TvShow show;
  final Episode episode;
  const EpisodeDetailScreen(
      {super.key, required this.show, required this.episode});

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  final TvTrackingService _tracking = TvTrackingService.instance;
  final TextEditingController _noteController = TextEditingController();
  bool _noteSeeded = false;

  late final Future<List<CastMember>> _cast = APIservices()
      .getCredits(MediaType.tv, widget.show.id)
      .catchError((_) => <CastMember>[]);
  late final Future<List<WatchProvider>> _providers = APIservices()
      .getWatchProviders(MediaType.tv, widget.show.id,
          WidgetsBinding.instance.platformDispatcher.locale.countryCode ??
              'US')
      .catchError((_) => <WatchProvider>[]);

  TvShow get show => widget.show;
  Episode get ep => widget.episode;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              l10n.episodeSeasonEpisodeLabel(ep.seasonNumber, ep.episodeNumber)),
          actions: [
            IconButton(
              icon: const Icon(Icons.tv_rounded),
              tooltip: show.name,
              onPressed: () => openMedia(context, show.toMediaItem()),
            ),
          ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: TmdbImage(
                url: Tmdb.still(ep.stillPath, size: 'w780'),
                placeholderIcon: Icons.tv_rounded,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('${ep.episodeNumber}. ${ep.name}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            [
              if (ep.airDate.isNotEmpty) ep.airDate,
              if (ep.runtime > 0) l10n.episodeRuntimeMinutes(ep.runtime),
              if (ep.voteAverage > 0)
                l10n.episodeRatingStars(ep.voteAverage.toStringAsFixed(1)),
              if (!ep.hasAired) l10n.episodeNotAiredYet,
            ].join('   •   '),
            style: TextStyle(color: context.colors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          _watchedButton(),
          if (ep.overview.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.episodeOverviewTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(ep.overview,
                style: TextStyle(
                    color: context.colors.textSecondary, height: 1.45)),
          ],
          const SizedBox(height: 22),
          _noteAndRating(),
          const SizedBox(height: 22),
          _pollSection(),
        ],
      ),
    );
  }

  Widget _watchedButton() {
    return StreamBuilder<Set<String>>(
      stream: _tracking.watchedKeysStream(show.id),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final watched = (snap.data ?? const <String>{}).contains(ep.key);
        return SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => _toggleWatched(watched),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: watched ? null : context.colors.brandGradient,
                color: watched ? context.colors.surfaceAlt : null,
                borderRadius: BorderRadius.circular(14),
                border: watched
                    ? Border.all(color: context.colors.primary, width: 1.2)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(watched ? Icons.check_rounded : Icons.add_rounded,
                      color: watched ? context.colors.primary : Colors.white,
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                      watched
                          ? l10n.episodeWatchedLabel
                          : l10n.episodeMarkAsWatchedLabel,
                      style: TextStyle(
                          color:
                              watched ? context.colors.primary : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleWatched(bool currentlyWatched) async {
    await _tracking.setEpisodeWatched(show, ep, !currentlyWatched);
    if (!currentlyWatched && mounted) _showPoll();
  }

  void _showPoll() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: FutureBuilder<List<CastMember>>(
            future: _cast,
            builder: (context, snap) => FutureBuilder<List<WatchProvider>>(
              future: _providers,
              builder: (context, provSnap) => PollCard(
                pollId: PollService.instance.episodePollId(
                    show.id, ep.seasonNumber, ep.episodeNumber),
                cast: snap.data ?? const [],
                providers: provSnap.data ?? const [],
                isMovie: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // "How was it?" poll — visible once this episode has been watched, so
  // users can answer/revisit it without waiting for the auto-popup.
  Widget _pollSection() {
    return StreamBuilder<Set<String>>(
      stream: _tracking.watchedKeysStream(show.id),
      builder: (context, snap) {
        final watched = (snap.data ?? const <String>{}).contains(ep.key);
        if (!watched) return const SizedBox.shrink();
        return FutureBuilder<List<CastMember>>(
          future: _cast,
          builder: (context, castSnap) => FutureBuilder<List<WatchProvider>>(
            future: _providers,
            builder: (context, provSnap) => PollCard(
              pollId: PollService.instance.episodePollId(
                  show.id, ep.seasonNumber, ep.episodeNumber),
              cast: castSnap.data ?? const [],
              providers: provSnap.data ?? const [],
              isMovie: false,
            ),
          ),
        );
      },
    );
  }

  Widget _noteAndRating() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _tracking.episodeNoteStream(show.id, ep.key),
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final data = snap.data;
        final rating = ((data?['rating'] ?? 0) as num).toDouble();
        // Seed the note field once, from the stored value.
        if (!_noteSeeded && data != null) {
          _noteController.text = (data['note'] ?? '') as String;
          _noteSeeded = true;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.episodeYourRatingTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: ValueKey(rating),
              child: RatingBar.builder(
                initialRating: rating,
                minRating: 0,
                allowHalfRating: true,
                itemCount: 5,
                glowColor: context.colors.accent,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, _) =>
                    Icon(Icons.star_rounded, color: context.colors.accent),
                onRatingUpdate: (r) async {
                  await _tracking.setEpisodeNote(show.id, ep.key, rating: r);
                  // Mirrored into the poll's read-only star row, which no
                  // longer asks for a score of its own.
                  await PollService.instance.syncRating(
                      PollService.instance.episodePollId(
                          show.id, ep.seasonNumber, ep.episodeNumber),
                      r);
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(l10n.episodeYourNotesTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l10n.episodeNotesPrivateHint,
                style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: l10n.episodeNoteHint,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final focus = FocusScope.of(context);
                  await _tracking.setEpisodeNote(show.id, ep.key,
                      note: _noteController.text.trim());
                  focus.unfocus();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.episodeNoteSaved)),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(l10n.episodeSaveNoteButton),
              ),
            ),
          ],
        );
      },
    );
  }
}
