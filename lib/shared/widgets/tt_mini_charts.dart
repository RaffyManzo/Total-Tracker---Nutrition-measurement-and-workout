import 'dart:math' as math;

import 'package:flutter/material.dart';

class TtChartPoint {
  const TtChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class TtMiniBarChart extends StatelessWidget {
  const TtMiniBarChart({
    required this.points,
    this.height = 136,
    this.valueSuffix = '',
    super.key,
  });

  final List<TtChartPoint> points;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('Nessun dato disponibile.');
    }
    final double maxValue = math.max(
      1,
      points.map((TtChartPoint point) => point.value).reduce(math.max),
    );
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final TtChartPoint point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${point.value.round()}$valueSuffix',
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor:
                            (point.value / maxValue).clamp(0.04, 1).toDouble(),
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.label,
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

class TtMiniLineChart extends StatelessWidget {
  const TtMiniLineChart({
    required this.points,
    this.height = 144,
    this.valueSuffix = '',
    super.key,
  });

  final List<TtChartPoint> points;
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
          color: Theme.of(context).colorScheme.primary,
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

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.color,
    required this.gridColor,
    required this.textStyle,
    required this.valueSuffix,
  });

  final List<TtChartPoint> points;
  final Color color;
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
    final double minValue =
        points.map((TtChartPoint point) => point.value).reduce(math.min);
    final double maxValue =
        points.map((TtChartPoint point) => point.value).reduce(math.max);
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
        oldDelegate.color != color ||
        oldDelegate.valueSuffix != valueSuffix;
  }
}
