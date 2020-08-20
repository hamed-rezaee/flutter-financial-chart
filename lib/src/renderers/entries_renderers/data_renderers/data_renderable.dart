import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_financial_chart/flutter_financial_chart.dart';
import 'package:flutter_financial_chart/src/chart/position_notifier.dart';
import 'package:flutter_financial_chart/src/models/animation_info.dart';
import 'package:flutter_financial_chart/src/models/data_series.dart';
import 'package:flutter_financial_chart/src/models/models.dart';
import 'package:flutter_financial_chart/src/renderers/entries_renderers/data_renderers/data_renderer_config.dart';
import 'package:flutter_financial_chart/src/util/helpers.dart';

import '../entries_renderable.dart';
import '../entries_renderer.dart';

/// Holds common options for current tick indicator, etc
/// Options be implemented here and each subclass of this will paint its own data
abstract class DataRendererable<T extends BaseEntry>
    extends EntriesRendererable<T> {
  DataRendererable({
    @required DataSeries<T> visibleEntries,
    @required IndexedData<T> lastEntry,
    @required int leftXFactor,
    @required int rightXFactor,
    Color lineColor,
    bool isIndependentChart,
    TouchInfo touchInfo,
    DataRenderer renderer,
    this.config,
  })  : _paint = Paint()
          ..color = lineColor ?? Colors.yellow
          ..style = PaintingStyle.fill
          ..strokeWidth = 0.5,
        super(
          visibleEntries: visibleEntries,
          lastEntry: lastEntry,
          leftXFactor: leftXFactor,
          rightXFactor: rightXFactor,
          isIndependentChart: isIndependentChart,
          touchInfo: touchInfo,
          renderer: renderer,
        );

  final Paint _paint;
  final DataRendererConfig config;

  @override
  void onPaint({
    Canvas canvas,
    Size size,
    AnimationsInfo animationsInfo,
    IndexedData<T> prevLastEntry,
  }) {
    // Draw common options
    final IndexedData<BaseEntry> lastVisibleEntry = visibleEntries.last;

    if (config.lastTickMarkerConfig != null &&
        renderer.xFactorDecider
                .getXFactor((renderer as EntriesRenderer).entries.last) <
            rightXFactor) {
      double animatedValue;
      if (prevLastEntry != null) {
        animatedValue = ui.lerpDouble(prevLastEntry.e.value,
            lastVisibleEntry.e.value, animationsInfo.newTickPercent);
      } else {
        animatedValue = ui.lerpDouble(
          0,
          lastVisibleEntry.e.value,
          animationsInfo.newTickPercent,
        );
      }

      final lastVisibleEntryX =
          xFactorToX(renderer.xFactorDecider.getXFactor(lastVisibleEntry));

      final animatedValueY = valueToY(animatedValue);

      _paint.color = Colors.yellow;

      _drawDashedLine(
          canvas, lastVisibleEntryX, animatedValueY, size, animatedValue);

      _drawLabel(
        animatedValue.toStringAsFixed(4),
        canvas,
        animatedValueY,
        size,
      );

      if (config.lastTickMarkerConfig.dotEnabled) {
        _drawAnimatedDot(
          lastVisibleEntryX,
          animatedValueY,
          canvas,
          animationsInfo.newTickPercent,
        );
      }
    }

    if ((config.tooltipConfig?.enabled ?? false) &&
        (touchInfo?.status == TouchStatus.tapDown ||
            touchInfo?.status == TouchStatus.tapUp) &&
        touchInfo.xFactor < rightXFactor &&
        touchInfo.xFactor > leftXFactor) {
      final entry = searchClosesEntry(
        touchInfo.xFactor,
        visibleEntries,
        renderer.xFactorDecider,
      );
      final entryTouchArea = getEntryTouchArea(entry);

      if (entryTouchArea.inflate(16).contains(
          Offset(xFactorToX(touchInfo.xFactor), valueToY(touchInfo.value)))) {
        final anchorPoint = getTooltipAnchorPoint(entry);
        final tooltipText = getTooltipText(entry);

        final size = 96 * animationsInfo.toolTipPercent;

        Paint tooltipPaint = Paint()..color = Colors.white70.withOpacity(0.5);

        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(anchorPoint.dx, anchorPoint.dy - size / 2),
                    width: size,
                    height: size),
                Radius.circular(4)),
            tooltipPaint);

        if (animationsInfo.toolTipPercent > 0.9) {
          _drawTextOn(
            tooltipText,
            canvas,
            anchorPoint.dx - size / 4,
            anchorPoint.dy - size * 3 / 4,
            size: Size(size, size),
          );
        }

        canvas.drawRRect(
            RRect.fromRectAndRadius(
                entryTouchArea.inflate(2), Radius.circular(2)),
            tooltipPaint);
      }
    }
  }

  String getTooltipText(IndexedData<T> entry);

  Offset getTooltipAnchorPoint(IndexedData<T> entry);

  Rect getEntryTouchArea(IndexedData<T> entry);

  void _drawAnimatedDot(
    double lastVisibleEntryX,
    double animatedValueY,
    ui.Canvas canvas,
    double newTickAnimationPercent,
  ) {
    canvas.drawCircle(Offset(lastVisibleEntryX, animatedValueY),
        3 + 3 * (1 - newTickAnimationPercent), _paint);

    Paint pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _paint.color.withOpacity((1 - newTickAnimationPercent) / 1.5);

    canvas.drawCircle(Offset(lastVisibleEntryX, animatedValueY),
        24 * newTickAnimationPercent, pulsePaint);

    _paint
      ..shader = ui.Gradient.linear(
        Offset(lastVisibleEntryX, 0),
        Offset(lastVisibleEntryX, animatedValueY + 15),
        [
          config.lastTickMarkerConfig.labelBackgroundColor.withOpacity(1),
          config.lastTickMarkerConfig.labelBackgroundColor.withOpacity(0.5),
        ],
      );
  }

  void _drawDashedLine(ui.Canvas canvas, double lastVisibleEntryX,
      double animatedValueY, ui.Size size, double animatedValue) {
    double startX = lastVisibleEntryX;
    final double dashWidth = 5;
    final double dashSpace = 10;
    while (startX <= size.width - config.lastTickMarkerConfig.labelWidth) {
      canvas.drawLine(Offset(startX, animatedValueY),
          Offset(startX + dashWidth, animatedValueY), _paint);
      startX += (dashSpace + dashWidth);
    }
  }

  void _drawLabel(String text, Canvas canvas, double y, Size size) {
    Path labelPath = Path();

    labelPath.moveTo(size.width - config.lastTickMarkerConfig.labelWidth, y);
    labelPath.lineTo(size.width - 0.8 * config.lastTickMarkerConfig.labelWidth,
        y - config.lastTickMarkerConfig.labelHeight / 2);
    labelPath.lineTo(
        size.width, y - config.lastTickMarkerConfig.labelHeight / 2);
    labelPath.lineTo(
        size.width, y + config.lastTickMarkerConfig.labelHeight / 2);
    labelPath.lineTo(size.width - 0.8 * config.lastTickMarkerConfig.labelWidth,
        y + config.lastTickMarkerConfig.labelHeight / 2);
    labelPath.lineTo(size.width - config.lastTickMarkerConfig.labelWidth, y);

    _paint.color = config.lastTickMarkerConfig.labelBackgroundColor;

    canvas.drawPath(labelPath, _paint);

    final textStyle = TextStyle(
      color: config.lastTickMarkerConfig.textColor,
      fontSize: 10,
    );
    final textSpan = TextSpan(
      text: text,
      style: textStyle,
    );
    final textPainter =
        TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 50, maxWidth: 50);
    textPainter.paint(canvas, Offset(size.width - 50, y - 5));
  }

  void _drawTextOn(
    String text,
    Canvas canvas,
    double x,
    double y, {
    Color color = Colors.black87,
    Size size = const Size(64, 64),
  }) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 10,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter =
        TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: size.width, maxWidth: size.height);
    textPainter.paint(canvas, Offset(x, y));
  }
}
