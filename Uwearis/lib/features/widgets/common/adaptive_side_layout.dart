import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Which edge of [AdaptiveSideLayout]'s content the side widget sits on.
enum AdaptiveSide {
  /// Before the content; stacks above it.
  leading,

  /// After the content; stacks below it, end-aligned.
  trailing,
}

/// Lays [side] (a decorative icon or a cluster of actions) beside [content],
/// or moves it above/below when [content]'s longest Latin word at the current
/// text size wouldn't fit beside it. Text then wraps between words instead of
/// inside them; CJK text wraps between any two characters, so it never
/// triggers the stacked arrangement on its own.
///
/// [content] gets the remaining width (like `Expanded`) and is vertically
/// centred within the layout's height.
class AdaptiveSideLayout extends MultiChildRenderObjectWidget {
  final AdaptiveSide sideEdge;
  final double gap;
  final double stackedGap;

  AdaptiveSideLayout({
    super.key,
    required Widget side,
    required Widget content,
    required this.sideEdge,
    required this.gap,
    required this.stackedGap,
  }) : super(children: [side, content]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAdaptiveSideLayout(
        sideEdge: sideEdge,
        gap: gap,
        stackedGap: stackedGap,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAdaptiveSideLayout renderObject,
  ) {
    renderObject
      ..sideEdge = sideEdge
      ..gap = gap
      ..stackedGap = stackedGap;
  }
}

final RegExp _word = RegExp(r"[A-Za-z0-9\u00C0-\u024F'’]+");

/// The widest Latin word (letters/digits) any paragraph under [root] will
/// render, at that paragraph's own style and text scale. Measured from the
/// text rather than `getMinIntrinsicWidth`, which reports a whole CJK run as
/// one unbreakable word even though CJK wraps between any two characters.
double longestWordWidth(RenderObject root) {
  var widest = 0.0;
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final style = node.text.style;
      for (final match in _word.allMatches(node.text.toPlainText())) {
        final painter = TextPainter(
          text: TextSpan(text: match[0], style: style),
          textDirection: TextDirection.ltr,
          textScaler: node.textScaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }
    node.visitChildren(visit);
  }

  visit(root);
  return widest;
}

class _SideParentData extends ContainerBoxParentData<RenderBox> {}

class RenderAdaptiveSideLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SideParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SideParentData> {
  RenderAdaptiveSideLayout({
    required AdaptiveSide sideEdge,
    required double gap,
    required double stackedGap,
  }) : _sideEdge = sideEdge,
       _gap = gap,
       _stackedGap = stackedGap;

  AdaptiveSide _sideEdge;
  set sideEdge(AdaptiveSide value) {
    if (value == _sideEdge) return;
    _sideEdge = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _stackedGap;
  set stackedGap(double value) {
    if (value == _stackedGap) return;
    _stackedGap = value;
    markNeedsLayout();
  }

  RenderBox get _side => firstChild!;
  RenderBox get _content => childAfter(firstChild!)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SideParentData) {
      child.parentData = _SideParentData();
    }
  }

  double get _sideWidth => _side.getMaxIntrinsicWidth(double.infinity);

  bool _stacksAt(double width) =>
      longestWordWidth(_content) > width - _sideWidth - _gap;

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _side.getMinIntrinsicWidth(height),
    _content.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _side.getMaxIntrinsicWidth(height) +
      _gap +
      _content.getMaxIntrinsicWidth(height);

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightOf,
  ) {
    if (!width.isFinite) {
      return math.max(
        heightOf(_side, double.infinity),
        heightOf(_content, double.infinity),
      );
    }
    if (_stacksAt(width)) {
      return heightOf(_side, width) + _stackedGap + heightOf(_content, width);
    }
    return math.max(
      heightOf(_side, _sideWidth),
      heightOf(_content, math.max(0, width - _sideWidth - _gap)),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (c, w) => c.getMaxIntrinsicHeight(w));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    assert(constraints.hasBoundedWidth);
    final width = constraints.maxWidth;
    final stacked = _stacksAt(width);
    final sideConstraints = BoxConstraints(maxWidth: width);
    final sideSize = dry
        ? _side.getDryLayout(sideConstraints)
        : (_side..layout(sideConstraints, parentUsesSize: true)).size;
    final contentWidth = stacked
        ? width
        : math.max(0.0, width - sideSize.width - _gap);
    final contentConstraints = BoxConstraints.tightFor(width: contentWidth);
    final contentSize = dry
        ? _content.getDryLayout(contentConstraints)
        : (_content..layout(contentConstraints, parentUsesSize: true)).size;

    final blockHeight = stacked
        ? sideSize.height + _stackedGap + contentSize.height
        : math.max(sideSize.height, contentSize.height);
    final size = constraints.constrain(Size(width, blockHeight));
    if (dry) return size;

    final top = (size.height - blockHeight) / 2;
    final sideData = _side.parentData! as _SideParentData;
    final contentData = _content.parentData! as _SideParentData;
    final leading = _sideEdge == AdaptiveSide.leading;
    if (stacked) {
      if (leading) {
        sideData.offset = Offset(0, top);
        contentData.offset = Offset(0, top + sideSize.height + _stackedGap);
      } else {
        contentData.offset = Offset(0, top);
        sideData.offset = Offset(
          width - sideSize.width,
          top + contentSize.height + _stackedGap,
        );
      }
    } else {
      final sideTop = top + (blockHeight - sideSize.height) / 2;
      final contentTop = top + (blockHeight - contentSize.height) / 2;
      if (leading) {
        sideData.offset = Offset(0, sideTop);
        contentData.offset = Offset(sideSize.width + _gap, contentTop);
      } else {
        contentData.offset = Offset(0, contentTop);
        sideData.offset = Offset(width - sideSize.width, sideTop);
      }
    }
    return size;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
