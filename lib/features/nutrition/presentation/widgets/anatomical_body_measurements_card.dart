import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AnatomicalBodyMeasurementsCard extends StatefulWidget {
  const AnatomicalBodyMeasurementsCard({
    required this.values,
    this.onRegionTap,
    this.onTapRegion,
    super.key,
  }) : assert(onRegionTap != null || onTapRegion != null);

  final Map<String, double?> values;
  final ValueChanged<String>? onRegionTap;
  final ValueChanged<String>? onTapRegion;

  @override
  State<AnatomicalBodyMeasurementsCard> createState() =>
      _AnatomicalBodyMeasurementsCardState();
}

class _AnatomicalBodyMeasurementsCardState
    extends State<AnatomicalBodyMeasurementsCard> {
  String? _selectedCode;
  String? _hoveredCode;
  Size? _geometrySize;
  _BodyGeometry? _geometry;

  _BodyGeometry _geometryFor(Size size) {
    if (_geometry == null || _geometrySize != size) {
      _geometrySize = size;
      _geometry = _BodyGeometry(size);
    }
    return _geometry!;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String activeCode = _hoveredCode ?? _selectedCode ?? 'chest_cm';
    final _BodyRegion activeRegion = _regionsByCode[activeCode]!;
    final double? value = widget.values[activeCode];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Corpo interattivo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Tocca una zona per registrare o modificare la misura.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double height = math.min(
                  560,
                  math.max(390, constraints.maxWidth * 1.16),
                );
                final Size bodySize = Size(
                  math.min(constraints.maxWidth, 430),
                  height,
                );
                final _BodyGeometry geometry = _geometryFor(bodySize);
                return Center(
                  child: SizedBox(
                    width: bodySize.width,
                    height: bodySize.height,
                    child: MouseRegion(
                      onHover: (PointerHoverEvent event) {
                        _setHovered(event.localPosition, bodySize);
                      },
                      onExit: (_) {
                        if (_hoveredCode != null) {
                          setState(() => _hoveredCode = null);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (TapUpDetails details) {
                          final String? code =
                              _hitTest(details.localPosition, bodySize);
                          if (code == null) return;
                          setState(() => _selectedCode = code);
                          (widget.onRegionTap ?? widget.onTapRegion)
                              ?.call(code);
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _AnatomicalBodyPainter(
                              geometry: geometry,
                              selectedCode: _selectedCode,
                              hoveredCode: _hoveredCode,
                              colorScheme: colors,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          activeRegion.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          value == null
                              ? 'Nessuna misura registrata'
                              : '${value.toStringAsFixed(1)} cm',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.touch_app_rounded, color: colors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setHovered(Offset position, Size size) {
    final String? code = _hitTest(position, size);
    if (code != _hoveredCode) {
      setState(() => _hoveredCode = code);
    }
  }

  String? _hitTest(Offset position, Size size) {
    final _BodyGeometry geometry = _geometryFor(size);
    for (final _BodyRegion region in _hitOrder) {
      if (geometry.hitPaths[region.code]?.contains(position) ?? false) {
        return region.code;
      }
    }
    return null;
  }
}

class _AnatomicalBodyPainter extends CustomPainter {
  const _AnatomicalBodyPainter({
    required this.geometry,
    required this.selectedCode,
    required this.hoveredCode,
    required this.colorScheme,
  });

  final _BodyGeometry geometry;
  final String? selectedCode;
  final String? hoveredCode;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    final Paint backgroundGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          colorScheme.primary.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(bounds)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    final Path glowPath = Path()
      ..moveTo(size.width * 0.24, size.height * 0.16)
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.42,
        size.width * 0.15,
        size.height * 0.83,
        size.width * 0.40,
        size.height * 0.96,
      )
      ..cubicTo(
        size.width * 0.58,
        size.height * 1.02,
        size.width * 0.84,
        size.height * 0.82,
        size.width * 0.78,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.17,
        size.width * 0.48,
        size.height * 0.04,
        size.width * 0.24,
        size.height * 0.16,
      )
      ..close();
    canvas.drawPath(glowPath, backgroundGlow);

    canvas.save();
    canvas.translate(0, size.height * 0.006);
    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
    canvas.drawPath(geometry.fullSilhouette, shadow);
    canvas.restore();

    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          colorScheme.surfaceContainerHighest,
          Color.lerp(
                colorScheme.surfaceContainerHighest,
                colorScheme.primaryContainer,
                0.22,
              ) ??
              colorScheme.surfaceContainerHighest,
          colorScheme.surfaceContainer,
        ],
        stops: const <double>[0, 0.48, 1],
      ).createShader(geometry.fullSilhouette.getBounds());
    canvas.drawPath(geometry.fullSilhouette, bodyPaint);

    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.004)
      ..color = colorScheme.outline.withValues(alpha: 0.48)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(geometry.fullSilhouette, edge);

    final Paint softContour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width * 0.003)
      ..color = colorScheme.onSurface.withValues(alpha: 0.12)
      ..strokeCap = StrokeCap.round;
    for (final Path contour in geometry.contours) {
      canvas.drawPath(contour, softContour);
    }

    final String? highlighted = hoveredCode ?? selectedCode;
    if (highlighted != null) {
      final Path? path = geometry.visualRegions[highlighted];
      if (path != null) {
        final Paint highlight = Paint()
          ..color = colorScheme.primary.withValues(
            alpha: hoveredCode != null ? 0.24 : 0.18,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawPath(path, highlight);
        final Paint highlightEdge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..color = colorScheme.primary.withValues(alpha: 0.72);
        canvas.drawPath(path, highlightEdge);
      }
    }

    final Paint facePaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.28)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final double cx = size.width / 2;
    canvas.drawLine(
      Offset(cx - size.width * 0.026, size.height * 0.098),
      Offset(cx - size.width * 0.008, size.height * 0.098),
      facePaint,
    );
    canvas.drawLine(
      Offset(cx + size.width * 0.008, size.height * 0.098),
      Offset(cx + size.width * 0.026, size.height * 0.098),
      facePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.126),
        width: size.width * 0.055,
        height: size.height * 0.026,
      ),
      0.15,
      math.pi - 0.3,
      false,
      facePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnatomicalBodyPainter oldDelegate) {
    return selectedCode != oldDelegate.selectedCode ||
        hoveredCode != oldDelegate.hoveredCode ||
        colorScheme != oldDelegate.colorScheme ||
        geometry.size != oldDelegate.geometry.size;
  }
}

class _BodyGeometry {
  _BodyGeometry(this.size) {
    _build();
  }

  final Size size;
  late final Path fullSilhouette;
  final Map<String, Path> hitPaths = <String, Path>{};
  final Map<String, Path> visualRegions = <String, Path>{};
  final List<Path> contours = <Path>[];

  double get w => size.width;
  double get h => size.height;
  double x(double value) => w * value;
  double y(double value) => h * value;

  void _build() {
    final Path head = Path()
      ..moveTo(x(0.455), y(0.055))
      ..cubicTo(x(0.46), y(0.018), x(0.54), y(0.018), x(0.545), y(0.055))
      ..cubicTo(x(0.563), y(0.075), x(0.554), y(0.136), x(0.525), y(0.151))
      ..cubicTo(x(0.512), y(0.161), x(0.488), y(0.161), x(0.475), y(0.151))
      ..cubicTo(x(0.446), y(0.136), x(0.437), y(0.075), x(0.455), y(0.055))
      ..close();

    final Path neck = Path()
      ..moveTo(x(0.474), y(0.145))
      ..cubicTo(x(0.478), y(0.17), x(0.47), y(0.184), x(0.452), y(0.192))
      ..lineTo(x(0.548), y(0.192))
      ..cubicTo(x(0.53), y(0.184), x(0.522), y(0.17), x(0.526), y(0.145))
      ..close();

    final Path torso = Path()
      ..moveTo(x(0.452), y(0.186))
      ..cubicTo(x(0.41), y(0.19), x(0.376), y(0.212), x(0.36), y(0.252))
      ..cubicTo(x(0.37), y(0.326), x(0.39), y(0.384), x(0.397), y(0.446))
      ..cubicTo(x(0.402), y(0.491), x(0.392), y(0.522), x(0.39), y(0.56))
      ..cubicTo(x(0.42), y(0.584), x(0.455), y(0.593), x(0.5), y(0.594))
      ..cubicTo(x(0.545), y(0.593), x(0.58), y(0.584), x(0.61), y(0.56))
      ..cubicTo(x(0.608), y(0.522), x(0.598), y(0.491), x(0.603), y(0.446))
      ..cubicTo(x(0.61), y(0.384), x(0.63), y(0.326), x(0.64), y(0.252))
      ..cubicTo(x(0.624), y(0.212), x(0.59), y(0.19), x(0.548), y(0.186))
      ..cubicTo(x(0.526), y(0.205), x(0.474), y(0.205), x(0.452), y(0.186))
      ..close();

    final Path leftArm = Path()
      ..moveTo(x(0.365), y(0.235))
      ..cubicTo(x(0.337), y(0.249), x(0.32), y(0.292), x(0.314), y(0.349))
      ..cubicTo(x(0.308), y(0.414), x(0.31), y(0.475), x(0.3), y(0.544))
      ..cubicTo(x(0.293), y(0.596), x(0.282), y(0.646), x(0.284), y(0.7))
      ..cubicTo(x(0.286), y(0.727), x(0.302), y(0.746), x(0.316), y(0.737))
      ..cubicTo(x(0.33), y(0.704), x(0.333), y(0.651), x(0.339), y(0.602))
      ..cubicTo(x(0.347), y(0.535), x(0.36), y(0.474), x(0.373), y(0.41))
      ..cubicTo(x(0.386), y(0.342), x(0.394), y(0.281), x(0.389), y(0.247))
      ..close();

    final Path rightArm = _mirror(leftArm);

    final Path leftLeg = Path()
      ..moveTo(x(0.397), y(0.548))
      ..cubicTo(x(0.383), y(0.616), x(0.386), y(0.686), x(0.394), y(0.75))
      ..cubicTo(x(0.402), y(0.812), x(0.399), y(0.872), x(0.39), y(0.934))
      ..cubicTo(x(0.386), y(0.966), x(0.397), y(0.984), x(0.426), y(0.982))
      ..cubicTo(x(0.449), y(0.975), x(0.452), y(0.954), x(0.452), y(0.928))
      ..cubicTo(x(0.451), y(0.864), x(0.46), y(0.804), x(0.469), y(0.742))
      ..cubicTo(x(0.478), y(0.678), x(0.483), y(0.618), x(0.48), y(0.574))
      ..close();
    final Path rightLeg = _mirror(leftLeg);

    fullSilhouette = Path()
      ..addPath(head, Offset.zero)
      ..addPath(neck, Offset.zero)
      ..addPath(torso, Offset.zero)
      ..addPath(leftArm, Offset.zero)
      ..addPath(rightArm, Offset.zero)
      ..addPath(leftLeg, Offset.zero)
      ..addPath(rightLeg, Offset.zero);

    Path region(double left, double top, double right, double bottom,
        {double radius = 0.02}) {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(x(left), y(top), x(right), y(bottom)),
          Radius.circular(math.min(w, h) * radius),
        ));
    }

    hitPaths.addAll(<String, Path>{
      'neck_cm': region(0.44, 0.14, 0.56, 0.205),
      'shoulders_cm': region(0.34, 0.185, 0.66, 0.265),
      'chest_cm': region(0.385, 0.245, 0.615, 0.35),
      'waist_cm': region(0.395, 0.375, 0.605, 0.46),
      'abdomen_cm': region(0.39, 0.445, 0.61, 0.525),
      'hips_cm': region(0.375, 0.515, 0.625, 0.6),
      'left_arm_cm': region(0.29, 0.245, 0.39, 0.44),
      'right_arm_cm': region(0.61, 0.245, 0.71, 0.44),
      'left_forearm_cm': region(0.275, 0.42, 0.355, 0.68),
      'right_forearm_cm': region(0.645, 0.42, 0.725, 0.68),
      'left_thigh_cm': region(0.37, 0.57, 0.49, 0.76),
      'right_thigh_cm': region(0.51, 0.57, 0.63, 0.76),
      'left_calf_cm': region(0.375, 0.75, 0.465, 0.94),
      'right_calf_cm': region(0.535, 0.75, 0.625, 0.94),
    });

    final Map<String, Path> visualBands = <String, Path>{
      'neck_cm': region(0.456, 0.145, 0.544, 0.205, radius: 0.025),
      'shoulders_cm': region(0.35, 0.185, 0.65, 0.265, radius: 0.035),
      'chest_cm': region(0.385, 0.245, 0.615, 0.35, radius: 0.045),
      'waist_cm': region(0.395, 0.375, 0.605, 0.46, radius: 0.04),
      'abdomen_cm': region(0.39, 0.44, 0.61, 0.525, radius: 0.04),
      'hips_cm': region(0.375, 0.51, 0.625, 0.605, radius: 0.04),
      'left_arm_cm': region(0.285, 0.235, 0.40, 0.44, radius: 0.03),
      'right_arm_cm': region(0.60, 0.235, 0.715, 0.44, radius: 0.03),
      'left_forearm_cm': region(0.27, 0.405, 0.365, 0.70, radius: 0.03),
      'right_forearm_cm': region(0.635, 0.405, 0.73, 0.70, radius: 0.03),
      'left_thigh_cm': region(0.37, 0.56, 0.495, 0.77, radius: 0.035),
      'right_thigh_cm': region(0.505, 0.56, 0.63, 0.77, radius: 0.035),
      'left_calf_cm': region(0.37, 0.74, 0.47, 0.95, radius: 0.03),
      'right_calf_cm': region(0.53, 0.74, 0.63, 0.95, radius: 0.03),
    };
    for (final MapEntry<String, Path> entry in visualBands.entries) {
      visualRegions[entry.key] = Path.combine(
        PathOperation.intersect,
        fullSilhouette,
        entry.value,
      );
    }

    contours.addAll(<Path>[
      Path()
        ..moveTo(x(0.405), y(0.36))
        ..cubicTo(x(0.45), y(0.375), x(0.55), y(0.375), x(0.595), y(0.36)),
      Path()
        ..moveTo(x(0.41), y(0.465))
        ..cubicTo(x(0.45), y(0.48), x(0.55), y(0.48), x(0.59), y(0.465)),
      Path()
        ..moveTo(x(0.5), y(0.205))
        ..cubicTo(x(0.493), y(0.28), x(0.495), y(0.46), x(0.5), y(0.56)),
      Path()
        ..moveTo(x(0.48), y(0.575))
        ..cubicTo(x(0.49), y(0.65), x(0.495), y(0.74), x(0.5), y(0.82)),
      Path()
        ..moveTo(x(0.52), y(0.575))
        ..cubicTo(x(0.51), y(0.65), x(0.505), y(0.74), x(0.5), y(0.82)),
    ]);
  }

  Path _mirror(Path source) {
    final Matrix4 matrix = Matrix4.identity()
      ..setEntry(0, 0, -1.0)
      ..setEntry(0, 3, w);
    return source.transform(matrix.storage);
  }
}

class _BodyRegion {
  const _BodyRegion(this.code, this.label);

  final String code;
  final String label;
}

const List<_BodyRegion> _hitOrder = <_BodyRegion>[
  _BodyRegion('neck_cm', 'Collo'),
  _BodyRegion('shoulders_cm', 'Spalle'),
  _BodyRegion('chest_cm', 'Torace'),
  _BodyRegion('waist_cm', 'Vita'),
  _BodyRegion('abdomen_cm', 'Addome'),
  _BodyRegion('hips_cm', 'Fianchi'),
  _BodyRegion('left_arm_cm', 'Braccio sinistro'),
  _BodyRegion('right_arm_cm', 'Braccio destro'),
  _BodyRegion('left_forearm_cm', 'Avambraccio sinistro'),
  _BodyRegion('right_forearm_cm', 'Avambraccio destro'),
  _BodyRegion('left_thigh_cm', 'Coscia sinistra'),
  _BodyRegion('right_thigh_cm', 'Coscia destra'),
  _BodyRegion('left_calf_cm', 'Polpaccio sinistro'),
  _BodyRegion('right_calf_cm', 'Polpaccio destro'),
];

final Map<String, _BodyRegion> _regionsByCode =
    Map<String, _BodyRegion>.unmodifiable(<String, _BodyRegion>{
  for (final _BodyRegion region in _hitOrder) region.code: region,
});
