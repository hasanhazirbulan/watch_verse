import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/services/poll_service.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// TV Time-style "how was it?" mini poll: platform watched on, emotion felt,
/// favorite character — each answered with a single tap, each revealing the
/// live cross-user percentage breakdown once answered.
class PollCard extends StatelessWidget {
  final String pollId;
  final List<CastMember> cast;
  final List<WatchProvider> providers;
  final bool isMovie;
  const PollCard({
    super.key,
    required this.pollId,
    required this.cast,
    this.providers = const [],
    required this.isMovie,
  });

  // Only the platforms people actually recognize — TMDB also returns rental/
  // channel-addon variants ("HBO Max Amazon Channel", "Prime Video with
  // Ads") that would otherwise show up as confusing near-duplicates right
  // next to the plain service. Matching by exact lowercase name (not a
  // substring) filters those out automatically, since addon entries always
  // carry a suffix that doesn't match the canonical name. The map value
  // groups regional/rebrand aliases (Max / HBO Max) onto one poll option.
  static const _knownProviders = {
    'netflix': 'netflix',
    'amazon prime video': 'prime',
    'prime video': 'prime',
    'disney plus': 'disney',
    'disney+': 'disney',
    'max': 'max',
    'hbo max': 'max',
    'apple tv+': 'appletv',
    'apple tv plus': 'appletv',
    'hulu': 'hulu',
    'paramount plus': 'paramount',
    'paramount+': 'paramount',
    'peacock': 'peacock',
    'blutv': 'blutv',
    'exxen': 'exxen',
    'gain': 'gain',
    'mubi': 'mubi',
  };

  List<WatchProvider> _wellKnownProviders() {
    final seenGroups = <String>{};
    final out = <WatchProvider>[];
    for (final p in providers) {
      final group = _knownProviders[p.name.trim().toLowerCase()];
      if (group != null && seenGroups.add(group)) out.add(p);
    }
    return out;
  }

  static const _emotionEmoji = {
    'happy': '😄',
    'confusing': '😕',
    'sad': '😢',
    'scary': '😱',
    'frustrating': '😤',
    'shocking': '😲',
    'exciting': '🤩',
    'boring': '😐',
  };

  String _emotionLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'happy':
        return l10n.pollEmotionHappy;
      case 'confusing':
        return l10n.pollEmotionConfusing;
      case 'sad':
        return l10n.pollEmotionSad;
      case 'scary':
        return l10n.pollEmotionScary;
      case 'frustrating':
        return l10n.pollEmotionFrustrating;
      case 'shocking':
        return l10n.pollEmotionShocking;
      case 'exciting':
        return l10n.pollEmotionExciting;
      default:
        return l10n.pollEmotionBoring;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.pollSectionTitle,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _PollRatingGroup(
            pollId: pollId,
            question: isMovie
                ? l10n.pollRatingQuestionMovie
                : l10n.pollRatingQuestionEpisode,
          ),
          Divider(height: 32, color: context.colors.surfaceAlt),
          _PollGroup(
            pollId: pollId,
            category: 'platform',
            question: l10n.pollPlatformQuestion,
            options: [
              if (isMovie)
                _PollOption(
                  key: 'cinema',
                  emoji: '🎬',
                  label: l10n.pollPlatformCinema,
                ),
              for (final p in _wellKnownProviders())
                _PollOption(
                  key: 'provider-${p.id}',
                  emoji: null,
                  label: p.name,
                  logoPath: p.logoPath,
                ),
              _PollOption(
                key: 'pirate',
                emoji: '🏴‍☠️',
                label: l10n.pollPlatformPirate,
              ),
            ],
          ),
          Divider(height: 32, color: context.colors.surfaceAlt),
          _PollGroup(
            pollId: pollId,
            category: 'emotion',
            question: l10n.pollEmotionQuestion,
            options: [
              for (final key in PollService.emotionOptions)
                _PollOption(
                  key: key,
                  emoji: _emotionEmoji[key],
                  label: _emotionLabel(l10n, key),
                ),
            ],
          ),
          if (cast.isNotEmpty) ...[
            Divider(height: 32, color: context.colors.surfaceAlt),
            _PollGroup(
              pollId: pollId,
              category: 'character',
              question: l10n.pollCharacterQuestion,
              horizontal: true,
              options: [
                for (final c in cast.take(8))
                  _PollOption(
                    key: c.id.toString(),
                    emoji: null,
                    label: c.character.isNotEmpty ? c.character : c.name,
                    profilePath: c.profilePath,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "RATE THIS EPISODE"-style 1-5 star rating. Distinct from [_PollGroup]
/// because star selection is cumulative (picking WOW fills all 5 stars,
/// unlike the single-choice emoji/platform tiles), and the label + percent
/// rows sit under a shared star row rather than each inside its own tile.
class _PollRatingGroup extends StatelessWidget {
  final String pollId;
  final String question;
  const _PollRatingGroup({required this.pollId, required this.question});

  static const _labels = ['bad', 'ok', 'good', 'great', 'wow'];

  String _labelText(AppLocalizations l10n, String key) {
    switch (key) {
      case 'bad':
        return l10n.pollRatingBad;
      case 'ok':
        return l10n.pollRatingOk;
      case 'good':
        return l10n.pollRatingGood;
      case 'great':
        return l10n.pollRatingGreat;
      default:
        return l10n.pollRatingWow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: PollService.instance.myAnswerStream(pollId),
      builder: (context, answerSnap) {
        final myPick = answerSnap.data?['rating'] as String?;
        final myStars = myPick == null ? 0 : _labels.indexOf(myPick) + 1;
        return StreamBuilder<Map<String, dynamic>?>(
          stream: PollService.instance.statsStream(pollId),
          builder: (context, statsSnap) {
            final stats = statsSnap.data;
            final counts =
                (stats?['ratingCounts'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
            final total = ((stats?['ratingTotal'] ?? 0) as num).toInt();
            final answered = myPick != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(question.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: context.colors.textSecondary)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (int i = 0; i < _labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => PollService.instance
                              .vote(pollId, 'rating', _labels[i]),
                          child: Icon(
                            i < myStars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 30,
                            color: i < myStars
                                ? context.colors.accent
                                : context.colors.textMuted
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final key in _labels)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _labelText(l10n, key).toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: context.colors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              answered
                                  ? '${total > 0 ? (((counts[key] ?? 0) as num).toInt() / total * 100).round() : 0}%'
                                  : '-',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: answered
                                      ? context.colors.textPrimary
                                      : context.colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PollOption {
  final String key;
  final String? emoji;
  final String label;
  final String? profilePath;
  final String? logoPath;
  const _PollOption({
    required this.key,
    required this.emoji,
    required this.label,
    this.profilePath,
    this.logoPath,
  });
}

/// One question (platform / emotion / character): a row of chips that starts
/// plain and, once this user has answered, shows every option's live
/// percentage of all votes with their own pick highlighted.
class _PollGroup extends StatelessWidget {
  final String pollId;
  final String category;
  final String question;
  final List<_PollOption> options;
  final bool horizontal;

  const _PollGroup({
    required this.pollId,
    required this.category,
    required this.question,
    required this.options,
    this.horizontal = false,
  });

  static const _columns = 4;
  static const _spacing = 10.0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: PollService.instance.myAnswerStream(pollId),
      builder: (context, answerSnap) {
        final myPick = answerSnap.data?[category] as String?;
        return StreamBuilder<Map<String, dynamic>?>(
          stream: PollService.instance.statsStream(pollId),
          builder: (context, statsSnap) {
            final stats = statsSnap.data;
            final counts =
                (stats?['${category}Counts'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
            final total = ((stats?['${category}Total'] ?? 0) as num).toInt();
            final showStats = myPick != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(question.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: context.colors.textSecondary)),
                ),
                const SizedBox(height: 14),
                if (horizontal)
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: options.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: _spacing),
                      itemBuilder: (context, i) {
                        final opt = options[i];
                        return SizedBox(
                          width: 78,
                          child: _PollTile(
                            option: opt,
                            selected: opt.key == myPick,
                            percent: showStats && total > 0
                                ? (((counts[opt.key] ?? 0) as num).toInt() /
                                        total *
                                        100)
                                    .round()
                                : null,
                            answered: showStats,
                            onTap: () => PollService.instance
                                .vote(pollId, category, opt.key),
                          ),
                        );
                      },
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tileWidth =
                          (constraints.maxWidth - _spacing * (_columns - 1)) /
                              _columns;
                      return Wrap(
                        spacing: _spacing,
                        runSpacing: _spacing,
                        children: [
                          for (final opt in options)
                            SizedBox(
                              width: tileWidth,
                              child: _PollTile(
                                option: opt,
                                selected: opt.key == myPick,
                                percent: showStats && total > 0
                                    ? (((counts[opt.key] ?? 0) as num)
                                                .toInt() /
                                            total *
                                            100)
                                        .round()
                                    : null,
                                answered: showStats,
                                onTap: () => PollService.instance
                                    .vote(pollId, category, opt.key),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// One tappable option tile: a circular emoji badge, an uppercase label and —
/// once the user has answered — the live percentage of all votes. The
/// selected tile gets a dark rounded-rect outline, mirroring TV Time's poll
/// cards where the pick stays visibly marked alongside the stats.
class _PollTile extends StatelessWidget {
  final _PollOption option;
  final bool selected;
  final int? percent;
  final bool answered;
  final VoidCallback onTap;

  const _PollTile({
    required this.option,
    required this.selected,
    required this.percent,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? context.colors.textPrimary : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _badge(context),
            const SizedBox(height: 7),
            Text(
              option.label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: context.colors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(
              answered ? '${percent ?? 0}%' : '-',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: answered
                      ? context.colors.textPrimary
                      : context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // TV Time shows the emoji bare on the card background — no colored circle
  // behind it — so plain emoji options render as a plain, larger glyph.
  // Only real images (actor photos, provider logos) get a frame, since an
  // unframed network image has no visual boundary of its own.
  Widget _badge(BuildContext context) {
    final logoUrl =
        option.logoPath != null ? Tmdb.logo(option.logoPath) : null;
    if (logoUrl != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: context.colors.surfaceAlt,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(logoUrl, fit: BoxFit.cover),
      );
    }
    final photoUrl = option.profilePath != null
        ? Tmdb.poster(option.profilePath, size: 'w185')
        : null;
    if (photoUrl != null) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: context.colors.surfaceAlt,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    if (option.emoji != null) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(option.emoji!, style: const TextStyle(fontSize: 30)),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.surfaceAlt,
      ),
      child: Text(
        option.label.isNotEmpty ? option.label[0].toUpperCase() : '?',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.textSecondary),
      ),
    );
  }
}
