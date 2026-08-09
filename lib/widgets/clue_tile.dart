import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:watch_verse/theme/app_theme.dart';

/// How a guessed movie's attribute compares to the mystery movie's — drives
/// the tile's revealed color (green/gold/gray, matching spotle.movie's own
/// clue-tile convention).
enum ClueMatch { exact, close, none }

/// One of the 8 clue tiles in the daily guessing game (Director, Studio,
/// Year, Box Office, Rating, Rated, Cast, Genres). Flips from a blank back
/// face to the revealed value on every new guess, staggered by [index] so a
/// row of 8 flips left-to-right like a Wordle reveal rather than all at
/// once.
class ClueTile extends StatefulWidget {
  final String label;
  final String value;
  final ClueMatch match;
  final int index;

  const ClueTile({
    super.key,
    required this.label,
    required this.value,
    required this.match,
    this.index = 0,
  });

  @override
  State<ClueTile> createState() => _ClueTileState();
}

class _ClueTileState extends State<ClueTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _playDelayed();
  }

  void _playDelayed() {
    Future.delayed(Duration(milliseconds: 90 * widget.index), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant ClueTile old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.match != widget.match) {
      _playDelayed();
    }
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
        return context.colors.surfaceAlt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
    final onColor =
        widget.match == ClueMatch.none ? context.colors.textPrimary : Colors.white;
    return _shell(
      color: _bg(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: onColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(widget.value.isEmpty ? '—' : widget.value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: onColor, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _shell({required Color color, required Widget child}) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
