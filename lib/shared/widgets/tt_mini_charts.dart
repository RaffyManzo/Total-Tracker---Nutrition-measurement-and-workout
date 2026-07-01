import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

class TtChartPoint {
  const TtChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class TtChartSeries {
  const TtChartSeries({
    required this.label,
    required this.points,
    this.color,
  });

  final String label;
  final List<TtChartPoint> points;
  final Color? color;
}

class TtMiniBarChart extends StatelessWidget {
  const TtMiniBarChart({
    required this.points,
    this.targetPoints = const <TtChartPoint>[],
    this.height = 136,
    this.valueSuffix = '',
    super.key,
  });

  final List<TtChartPoint> points;
  final List<TtChartPoint> targetPoints;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('Nessun dato disponibile.');
    }
    final List<double> values = <double>[
      for (final TtChartPoint point in points) point.value,
      for (final TtChartPoint point in targetPoints) point.value,
    ];
    final double maxValue = math.max(1, values.reduce(math.max));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int index = 0; index < points.length; index += 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${points[index].value.round()}$valueSuffix',
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: LayoutBuilder(
                        builder: (
                          BuildContext context,
                          BoxConstraints constraints,
                        ) {
                          final double? target = index < targetPoints.length
                              ? targetPoints[index].value
                              : null;
                          final double targetBottom = target == null
                              ? 0
                              : (target / maxValue).clamp(0, 1).toDouble() *
                                  constraints.maxHeight;
                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: <Widget>[
                              FractionallySizedBox(
                                heightFactor: (points[index].value / maxValue)
                                    .clamp(0.04, 1)
                                    .toDouble(),
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              if (target != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: (targetBottom - 1)
                                      .clamp(0, constraints.maxHeight)
                                      .toDouble(),
                                  child: CustomPaint(
                                    painter: _DashedHorizontalPainter(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    child: const SizedBox(height: 2),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      points[index].label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedHorizontalPainter extends CustomPainter {
  const _DashedHorizontalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, 1), Offset(math.min(x + 5, size.width), 1), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedHorizontalPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class TtMiniLineChart extends StatelessWidget {
  const TtMiniLineChart({
    required this.points,
    this.targetPoints = const <TtChartPoint>[],
    this.height = 144,
    this.valueSuffix = '',
    super.key,
  });

  final List<TtChartPoint> points;
  final List<TtChartPoint> targetPoints;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Text('Servono almeno due dati per mostrare il trend.');
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LineChartPainter(
          points: points,
          targetPoints: targetPoints,
          color: Theme.of(context).colorScheme.primary,
          targetColor: Theme.of(context).colorScheme.secondary,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          textStyle: Theme.of(context).textTheme.labelSmall ??
              const TextStyle(fontSize: 11),
          valueSuffix: valueSuffix,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class TtMiniMultiLineChart extends StatelessWidget {
  const TtMiniMultiLineChart({
    required this.series,
    this.height = 168,
    this.valueSuffix = '',
    super.key,
  });

  final List<TtChartSeries> series;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final List<TtChartSeries> drawable =
        series.where((TtChartSeries item) => item.points.length >= 2).toList();
    if (drawable.isEmpty) {
      return const Text('Servono almeno due dati per mostrare il trend.');
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
    ];
    final List<TtChartSeries> colored = <TtChartSeries>[
      for (int index = 0; index < drawable.length; index += 1)
        TtChartSeries(
          label: drawable[index].label,
          points: drawable[index].points,
          color: drawable[index].color ?? palette[index % palette.length],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _MultiLineChartPainter(
              series: colored,
              gridColor: scheme.outlineVariant,
              textStyle: Theme.of(context).textTheme.labelSmall ??
                  const TextStyle(fontSize: 11),
              valueSuffix: valueSuffix,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: <Widget>[
            for (final TtChartSeries item in colored)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const SizedBox.square(dimension: 9),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MultiLineChartPainter extends CustomPainter {
  const _MultiLineChartPainter({
    required this.series,
    required this.gridColor,
    required this.textStyle,
    required this.valueSuffix,
  });

  final List<TtChartSeries> series;
  final Color gridColor;
  final TextStyle textStyle;
  final String valueSuffix;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 8;
    const double top = 10;
    const double bottom = 24;
    const double right = 8;
    final double chartWidth = size.width - left - right;
    final double chartHeight = size.height - top - bottom;
    final Iterable<double> values = series.expand(
      (TtChartSeries item) =>
          item.points.map((TtChartPoint point) => point.value),
    );
    final double minValue = values.reduce(math.min);
    final double maxValue = values.reduce(math.max);
    final double range = math.max(1, maxValue - minValue);
    final int maxLength =
        series.map((TtChartSeries item) => item.points.length).reduce(math.max);
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i += 1) {
      final double y = top + chartHeight * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }
    for (final TtChartSeries item in series) {
      final Paint linePaint = Paint()
        ..color = item.color!
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final Path path = Path();
      for (int index = 0; index < item.points.length; index += 1) {
        final double x = left +
            chartWidth *
                index /
                math.max(
                    1,
                    item.points.length == 1
                        ? maxLength - 1
                        : item.points.length - 1);
        final double normalized = (item.points[index].value - minValue) / range;
        final double y = top + chartHeight * (1 - normalized);
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
      final Paint dotPaint = Paint()..color = item.color!;
      for (int index = 0; index < item.points.length; index += 1) {
        final double x = left +
            chartWidth *
                index /
                math.max(
                    1,
                    item.points.length == 1
                        ? maxLength - 1
                        : item.points.length - 1);
        final double normalized = (item.points[index].value - minValue) / range;
        final double y = top + chartHeight * (1 - normalized);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }
    _drawText(
      canvas,
      size,
      left,
      '${maxValue.toStringAsFixed(1)}$valueSuffix',
      Offset(left, 0),
    );
    final List<TtChartPoint> lastPoints = series.last.points;
    _drawText(
      canvas,
      size,
      left,
      lastPoints.last.label,
      Offset(size.width - 48, size.height - 18),
    );
  }

  void _drawText(
    Canvas canvas,
    Size size,
    double left,
    String text,
    Offset offset,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - left * 2);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.valueSuffix != valueSuffix;
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.targetPoints,
    required this.color,
    required this.targetColor,
    required this.gridColor,
    required this.textStyle,
    required this.valueSuffix,
  });

  final List<TtChartPoint> points;
  final List<TtChartPoint> targetPoints;
  final Color color;
  final Color targetColor;
  final Color gridColor;
  final TextStyle textStyle;
  final String valueSuffix;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 8;
    const double top = 10;
    const double bottom = 24;
    const double right = 8;
    final double chartWidth = size.width - left - right;
    final double chartHeight = size.height - top - bottom;
    final List<double> values = <double>[
      for (final TtChartPoint point in points) point.value,
      for (final TtChartPoint point in targetPoints) point.value,
    ];
    final double minValue = values.reduce(math.min);
    final double maxValue = values.reduce(math.max);
    final double range = math.max(1, maxValue - minValue);
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i += 1) {
      final double y = top + chartHeight * i / 2;
      canvas.drawLine(
          Offset(left, y), Offset(size.width - right, y), gridPaint);
    }
    final Path path = Path();
    for (int index = 0; index < points.length; index += 1) {
      final double x = left + chartWidth * index / (points.length - 1);
      final double normalized = (points[index].value - minValue) / range;
      final double y = top + chartHeight * (1 - normalized);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
    if (targetPoints.length >= 2) {
      final Path targetPath = Path();
      for (int index = 0; index < targetPoints.length; index += 1) {
        final double x = left + chartWidth * index / (targetPoints.length - 1);
        final double normalized =
            (targetPoints[index].value - minValue) / range;
        final double y = top + chartHeight * (1 - normalized);
        if (index == 0) {
          targetPath.moveTo(x, y);
        } else {
          targetPath.lineTo(x, y);
        }
      }
      _drawDashedPath(
        canvas,
        targetPath,
        Paint()
          ..color = targetColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    final Paint dotPaint = Paint()..color = color;
    for (int index = 0; index < points.length; index += 1) {
      final double x = left + chartWidth * index / (points.length - 1);
      final double normalized = (points[index].value - minValue) / range;
      final double y = top + chartHeight * (1 - normalized);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
    _drawText(canvas, size, left, '${maxValue.toStringAsFixed(1)}$valueSuffix',
        Offset(left, 0));
    _drawText(
      canvas,
      size,
      left,
      points.last.label,
      Offset(size.width - 48, size.height - 18),
    );
  }

  void _drawText(
    Canvas canvas,
    Size size,
    double left,
    String text,
    Offset offset,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - left * 2);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.targetPoints != targetPoints ||
        oldDelegate.color != color ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.valueSuffix != valueSuffix;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      const double dash = 7;
      const double gap = 5;
      while (distance < metric.length) {
        final double next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }
}
