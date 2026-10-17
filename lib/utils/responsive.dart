import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Window-size classes by *available width*, never by device type, idiom or
/// orientation — the same width can be a landscape phone, the folded or
/// unfolded iPhone Duo, or a resized window, and folding resizes a running
/// app mid-session.
///
/// Every helper here returns the phone value below [Breakpoints.medium], so
/// regular iPhones (≤ 440 pt wide in portrait) lay out exactly as before.
enum WindowSize { compact, medium, expanded }

abstract final class Breakpoints {
  /// Below this is a phone-width ("compact") layout.
  static const double medium = 600;

  /// At and above this, an iPad-style "expanded" layout (e.g. the Duo's
  /// inner display in landscape, 951 pt).
  static const double expanded = 840;

  /// Max width for reading / form-like content (settings, sheets, cards).
  static const double readable = 640;

  /// Max width for detail-page bodies, which carry rails and wider sections.
  static const double content = 720;

  static WindowSize of(double width) => width >= expanded
      ? WindowSize.expanded
      : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;
}

/// Horizontal inset that centers a column of at most [maxWidth] inside
/// [width]. Zero whenever the content already fits — i.e. on every phone.
double centeredInset(double width, {double maxWidth = Breakpoints.readable}) =>
    math.max(0, (width - maxWidth) / 2);

/// Column count for a poster grid: [compact] (the phone layout, unchanged)
/// below 600 pt, otherwise as many columns of at least [minTileWidth] as fit.
int posterColumns(
  double width, {
  int compact = 3,
  double minTileWidth = 150,
}) {
  if (width < Breakpoints.medium) return compact;
  return math.max(compact, (width / minTileWidth).floor());
}

/// Drop-in for `SliverGridDelegateWithFixedCrossAxisCount` whose column
/// count follows the grid's own width via [posterColumns]: [compactCount]
/// columns on phones (unchanged), more on wide windows instead of the same
/// few posters blown up to tablet size.
class SliverGridDelegateWithAdaptiveCount extends SliverGridDelegate {
  const SliverGridDelegateWithAdaptiveCount({
    this.compactCount = 3,
    this.minTileWidth = 150,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.mainAxisExtent,
  });

  final int compactCount;
  final double minTileWidth;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final double? mainAxisExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: posterColumns(constraints.crossAxisExtent,
          compact: compactCount, minTileWidth: minTileWidth),
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      mainAxisExtent: mainAxisExtent,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithAdaptiveCount oldDelegate) =>
      oldDelegate.compactCount != compactCount ||
      oldDelegate.minTileWidth != minTileWidth ||
      oldDelegate.mainAxisSpacing != mainAxisSpacing ||
      oldDelegate.crossAxisSpacing != crossAxisSpacing ||
      oldDelegate.childAspectRatio != childAspectRatio ||
      oldDelegate.mainAxisExtent != mainAxisExtent;
}

/// Column count for lists of row-shaped cards (Up Next, Watchlist, search
/// results): 1 on phones, then as many columns of at least [minColumnWidth]
/// as fit, capped at [max]. Keeps a 669 pt-wide window from stretching one
/// card edge to edge.
int listColumns(double width, {double minColumnWidth = 300, int max = 3}) {
  if (width < Breakpoints.medium) return 1;
  return (width / minColumnWidth).floor().clamp(1, max);
}

/// Lays [children] out [columns] per row (top-aligned, equal widths), for
/// splitting a vertical list into columns. Empty trailing cells keep the
/// last row's items the same width as the rest.
List<Widget> rowsOf(
  List<Widget> children,
  int columns, {
  double spacing = 12,
}) {
  if (columns <= 1) return children;
  return [
    for (var i = 0; i < children.length; i += columns)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) SizedBox(width: spacing),
            Expanded(
              child: i + c < children.length
                  ? children[i + c]
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
  ];
}

/// Centers [child] in a column at most [maxWidth] wide. A no-op
/// on phones (anything narrower than [maxWidth]).
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    this.maxWidth = Breakpoints.readable,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Side padding rather than Align + ConstrainedBox: the child keeps the
    // incoming constraints' tightness (a body stays full height, a stretched
    // Column stays stretched), just narrower.
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.hasBoundedWidth
            ? centeredInset(constraints.maxWidth, maxWidth: maxWidth)
            : 0.0;
        if (inset == 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: child,
        );
      },
    );
  }
}

/// Sliver counterpart of [ReadableWidth]: pads [sliver] so its content is
/// centered at most [maxWidth] wide, while the scroll view itself (and its
/// drag area) stays full width.
class SliverReadableWidth extends StatelessWidget {
  const SliverReadableWidth({
    super.key,
    this.maxWidth = Breakpoints.readable,
    required this.sliver,
  });

  final double maxWidth;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final inset =
            centeredInset(constraints.crossAxisExtent, maxWidth: maxWidth);
        if (inset == 0) return sliver;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          sliver: sliver,
        );
      },
    );
  }
}

/// A scroll view's [padding] plus whatever extra horizontal inset centers its
/// content at [maxWidth] — keeps the whole width draggable, unlike wrapping
/// the scroll view in [ReadableWidth].
///
/// With [alignStart] the column hugs the leading edge instead (all of the
/// extra space goes to the right).
EdgeInsets readablePadding(
  BoxConstraints constraints,
  EdgeInsets padding, {
  double maxWidth = Breakpoints.readable,
  bool alignStart = false,
}) {
  final inset = centeredInset(constraints.maxWidth, maxWidth: maxWidth);
  if (inset == 0) return padding;
  return padding.copyWith(
    left: padding.left + (alignStart ? 0 : inset),
    right: padding.right + (alignStart ? 2 * inset : inset),
  );
}

/// A vertical list that becomes [listColumns] columns on wide windows. On
/// phones it is exactly `ListView.builder` / `ListView.separated` with the
/// same arguments. In columns, [separatorBuilder] (if any) is drawn under
/// each item in its own column rather than across the whole row.
class AdaptiveListView extends StatelessWidget {
  const AdaptiveListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.physics,
    this.minColumnWidth = 300,
    this.columnSpacing = 16,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final double minColumnWidth;
  final double columnSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            listColumns(constraints.maxWidth, minColumnWidth: minColumnWidth);
        final sep = separatorBuilder;
        if (columns == 1) {
          return sep == null
              ? ListView.builder(
                  padding: padding,
                  physics: physics,
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                )
              : ListView.separated(
                  padding: padding,
                  physics: physics,
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                  separatorBuilder: sep,
                );
        }
        final rows = (itemCount / columns).ceil();
        return ListView.builder(
          padding: padding,
          physics: physics,
          itemCount: rows,
          itemBuilder: (context, row) {
            Widget cell(int i) {
              if (i >= itemCount) return const SizedBox.shrink();
              final item = itemBuilder(context, i);
              if (sep == null || row == rows - 1) return item;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [item, sep(context, i)],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) SizedBox(width: columnSpacing),
                  Expanded(child: cell(row * columns + c)),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Keeps every screen clear of side insets — the landscape notch / Dynamic
/// Island and, with the iOS 27.1 SDK, a status bar that can sit on a side
/// edge — by insetting the whole app horizontally and filling the strips
/// with [color]. Top/bottom insets stay with each screen (app bars, the tab
/// bar and SafeAreas already handle those). Zero on portrait phones, so it
/// changes nothing there. Used as `MaterialApp.builder`.
class SideSafeArea extends StatelessWidget {
  const SideSafeArea({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: color,
      child: _SideInsets(
        left: padding.left,
        right: padding.right,
        child: SafeArea(top: false, bottom: false, child: child),
      ),
    );
  }
}

/// The side insets [SideSafeArea] took away, for [FullBleed].
class _SideInsets extends InheritedWidget {
  const _SideInsets(
      {required this.left, required this.right, required super.child});

  final double left;
  final double right;

  @override
  bool updateShouldNotify(_SideInsets old) =>
      left != old.left || right != old.right;
}

/// Lets a purely decorative background (a backdrop image, its blur and
/// gradients) extend back under the side insets [SideSafeArea] keeps content
/// out of, so a side status bar sits over the image instead of a blank strip.
/// Never put interactive content in it. A no-op when there are no side
/// insets (portrait phones). Needs bounded constraints.
class FullBleed extends StatelessWidget {
  const FullBleed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final insets = context.dependOnInheritedWidgetOfExactType<_SideInsets>();
    if (insets == null || (insets.left == 0 && insets.right == 0)) {
      return child;
    }
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned(
          left: -insets.left,
          right: -insets.right,
          top: 0,
          bottom: 0,
          child: child,
        ),
      ],
    );
  }
}

/// Drop-in for [Center] for content that may not fit a short window (the
/// iPhone Duo's outer display, a landscape phone): centered when it fits,
/// scrollable instead of overflowing when it doesn't.
class ScrollableCenter extends StatelessWidget {
  const ScrollableCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            minHeight:
                constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Drop-in for [Padding] that also centers its child at most [maxWidth]
/// wide (extra horizontal inset on wide windows; plain [padding] on phones).
class ReadablePadding extends StatelessWidget {
  const ReadablePadding({
    super.key,
    this.maxWidth = Breakpoints.readable,
    this.alignStart = false,
    required this.padding,
    required this.child,
  });

  final double maxWidth;

  /// Hug the leading edge rather than center (see [readablePadding]).
  final bool alignStart;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: constraints.hasBoundedWidth
            ? readablePadding(constraints, padding,
                maxWidth: maxWidth, alignStart: alignStart)
            : padding,
        child: child,
      ),
    );
  }
}

/// Drop-in for [SingleChildScrollView] (vertical) whose child sits in a
/// centered column at most [maxWidth] wide; the scroll view itself stays
/// full width. Identical to SingleChildScrollView on phones.
class ReadableScrollView extends StatelessWidget {
  const ReadableScrollView({
    super.key,
    this.maxWidth = Breakpoints.readable,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.physics,
    required this.child,
  });

  final double maxWidth;
  final EdgeInsets padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: readablePadding(constraints, padding, maxWidth: maxWidth),
        controller: controller,
        physics: physics,
        child: child,
      ),
    );
  }
}

/// Drop-in for [ListView] (plain, `.builder`, `.separated`) whose items sit
/// in a centered column at most [maxWidth] wide, while the list itself —
/// and so its drag area and scroll bar — stays full width. Identical to the
/// plain ListView on phones.
class ReadableListView extends StatelessWidget {
  const ReadableListView({
    super.key,
    this.maxWidth = Breakpoints.readable,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    required List<Widget> this.children,
  })  : itemCount = null,
        itemBuilder = null,
        separatorBuilder = null;

  const ReadableListView.builder({
    super.key,
    this.maxWidth = Breakpoints.readable,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
  })  : children = null,
        separatorBuilder = null;

  const ReadableListView.separated({
    super.key,
    this.maxWidth = Breakpoints.readable,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    required IndexedWidgetBuilder this.separatorBuilder,
  }) : children = null;

  final double maxWidth;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final List<Widget>? children;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = centeredInset(constraints.maxWidth, maxWidth: maxWidth);
        var effective = padding;
        if (inset > 0) {
          // Mirror ListView's default of padding by the vertical safe area
          // when no padding was given.
          final base = padding ??
              MediaQuery.paddingOf(context).copyWith(left: 0, right: 0);
          effective = base.copyWith(
              left: base.left + inset, right: base.right + inset);
        }
        if (children != null) {
          return ListView(
            padding: effective,
            controller: controller,
            physics: physics,
            shrinkWrap: shrinkWrap,
            children: children!,
          );
        }
        if (separatorBuilder != null) {
          return ListView.separated(
            padding: effective,
            controller: controller,
            physics: physics,
            shrinkWrap: shrinkWrap,
            itemCount: itemCount!,
            itemBuilder: itemBuilder!,
            separatorBuilder: separatorBuilder!,
          );
        }
        return ListView.builder(
          padding: effective,
          controller: controller,
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: itemCount!,
          itemBuilder: itemBuilder!,
        );
      },
    );
  }
}
