import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:watch_verse/services/daily_game_clues.dart';
import 'package:watch_verse/theme/app_theme.dart';

export 'package:watch_verse/services/daily_game_clues.dart'
    show ClueMatch, ClueDirection;

/// One of the 8 clue tiles in the daily guessing game (Director, Studio,
/// Year, Box Office, Rating, Rated, Cast, Genres). With [animate], flips
/// from a blank back face to the revealed value, staggered by [index] so a
/// row of 8 flips left-to-right like a Wordle reveal rather than all at
/// once; without it (older guesses, revisiting a day) it's shown revealed
/// straight away instead of replaying the flip on every scroll/rebuild.
class ClueTile extends StatefulWidget {
  final String label;
  final String value;
  final ClueMatch match;
  final ClueDirection direction;
  final int index;
  final bool animate;

  const ClueTile({
    super.key,
    required this.label,
    required this.value,
    required this.match,
    this.direction = ClueDirection.none,
    this.index = 0,
    this.animate = true,
  });

  @override
  State<ClueTile> createState() => _ClueTileState();
}

class _ClueTileState extends State<ClueTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _playDelayed();
  }

  void _playDelayed() {
    Future.delayed(Duration(milliseconds: 90 * widget.index), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _bg(BuildContext context) {
    switch (widget.match) {
      case ClueMatch.exact:
        return context.colors.success;
      case ClueMatch.close:
        return context.colors.accent;
      case ClueMatch.none:
      case ClueMatch.unknown:
        return context.colors.surfaceAlt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrow = switch (widget.direction) {
      ClueDirection.higher => ' ↑',
      ClueDirection.lower => ' ↓',
      ClueDirection.none => '',
    };
    return Semantics(
      label: '${widget.label}: ${widget.value}$arrow',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          final showBack = angle <= math.pi / 2;
          final displayAngle = showBack ? angle : angle - math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(displayAngle),
            child: showBack ? _backFace(context) : _frontFace(context),
          );
        },
      ),
    );
  }

  Widget _backFace(BuildContext context) {
    return _shell(
      color: context.colors.surfaceAlt,
      child: Text(widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _frontFace(BuildContext context) {
    final bg = _bg(context);
    // Pick the text color by the tile's own brightness: the dark theme's
    // green/gold are light colors, and white on them was barely readable.
    final onColor = switch (widget.match) {
      ClueMatch.none || ClueMatch.unknown => context.colors.textPrimary,
      _ => bg.computeLuminance() > 0.4 ? Colors.black87 : Colors.white,
    };
    final unknown = widget.match == ClueMatch.unknown;
    return _shell(
      color: bg,
      // Dashed-looking outline for "no data" so it reads differently from a
      // real gray miss.
      border: unknown
          ? Border.all(color: context.colors.textMuted.withValues(alpha: 0.5))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: onColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(widget.value.isEmpty ? '?' : widget.value,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: unknown ? context.colors.textMuted : onColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              if (widget.direction != ClueDirection.none)
                Icon(
                  widget.direction == ClueDirection.higher
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 15,
                  color: onColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shell(
      {required Color color, required Widget child, BoxBorder? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
