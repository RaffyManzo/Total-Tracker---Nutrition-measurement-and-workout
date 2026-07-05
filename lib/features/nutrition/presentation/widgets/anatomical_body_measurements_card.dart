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
  Size? _cachedSize;
  _BodyGeometry? _cachedGeometry;

  _BodyGeometry _geometryFor(Size size) {
    if (_cachedGeometry == null || _cachedSize != size) {
      _cachedSize = size;
      _cachedGeometry = _BodyGeometry(size);
    }
    return _cachedGeometry!;
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

  void _selectRegion(String code) {
    setState(() => _selectedCode = code);
    (widget.onRegionTap ?? widget.onTapRegion)?.call(code);
  }

  String _valueText(String code) {
    final double? value = widget.values[code];
    if (value == null || !value.isFinite || value <= 0) {
      return 'Nessuna misura registrata';
    }
    final String formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted cm';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? activeCode = _hoveredCode ?? _selectedCode;
    final _BodyRegion? activeRegion =
        activeCode == null ? null : _regionsByCode[activeCode];

    return Semantics(
      container: true,
      label: 'Corpo interattivo per le misure corporee',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Misure corporee',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tocca una zona del corpo per inserire o aggiornare la misura.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double bodyWidth =
                    constraints.maxWidth.clamp(220.0, 340.0).toDouble();
                final Size bodySize = Size(bodyWidth, bodyWidth / 0.66);
                final _BodyGeometry geometry = _geometryFor(bodySize);

                return Center(
                  child: SizedBox.fromSize(
                    size: bodySize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onHover: (PointerHoverEvent event) {
                        final String? code =
                            _hitTest(event.localPosition, bodySize);
                        if (code != _hoveredCode) {
                          setState(() => _hoveredCode = code);
                        }
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
                          if (code != null) {
                            _selectRegion(code);
                          }
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
                color: activeRegion == null
                    ? colors.surfaceContainerHighest
                    : colors.primaryContainer.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: activeRegion == null
                      ? colors.outlineVariant
                      : colors.primary.withValues(alpha: 0.34),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: activeRegion == null
                          ? colors.outline
                          : colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: activeRegion == null
                        ? Text(
                            'Seleziona collo, torace, vita, arti o fianchi.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                activeRegion.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _valueText(activeRegion.code),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (activeRegion != null)
                    Icon(
                      Icons.edit_rounded,
                      size: 19,
                      color: colors.onPrimaryContainer,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final Paint backgroundPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.46);
    final RRect background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    canvas.drawRRect(background, backgroundPaint);

    final Paint haloPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.055);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.53),
        width: size.width * 0.72,
        height: size.height * 0.88,
      ),
      haloPaint,
    );

    final Color skin = Color.alphaBlend(
      colorScheme.tertiary.withValues(alpha: 0.10),
      const Color(0xFFF1B78F),
    );
    final Color skinShade = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.09),
      const Color(0xFFD98F68),
    );
    final Color topColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.82),
      colorScheme.surface,
    );
    final Color shortsColor = Color.alphaBlend(
      colorScheme.secondary.withValues(alpha: 0.76),
      colorScheme.surface,
    );
    final Color outline = colorScheme.onSurface.withValues(alpha: 0.44);

    final Paint skinPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = skin;
    final Paint skinShadePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = skinShade.withValues(alpha: 0.42);
    final Paint outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.006
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = outline;

    for (final Path path in geometry.skinParts) {
      canvas.drawPath(path, skinPaint);
      canvas.drawPath(path, outlinePaint);
    }

    canvas.drawPath(geometry.torso, skinPaint);
    canvas.drawPath(geometry.torso, outlinePaint);
    canvas.drawPath(
      geometry.tankTop,
      Paint()
        ..style = PaintingStyle.fill
        ..color = topColor,
    );
    canvas.drawPath(
      geometry.tankTop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.006
        ..strokeJoin = StrokeJoin.round
        ..color = colorScheme.primary.withValues(alpha: 0.68),
    );

    canvas.drawPath(
      geometry.shorts,
      Paint()
        ..style = PaintingStyle.fill
        ..color = shortsColor,
    );
    canvas.drawPath(
      geometry.shorts,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.006
        ..strokeJoin = StrokeJoin.round
        ..color = colorScheme.secondary.withValues(alpha: 0.70),
    );

    canvas.drawPath(geometry.neckShade, skinShadePaint);

    final Paint hairPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.12),
        const Color(0xFF49372F),
      );
    canvas.drawPath(geometry.hair, hairPaint);

    _paintFace(canvas, size, outline);
    _paintMeasurementBands(canvas, size);

    final String? activeCode = hoveredCode ?? selectedCode;
    if (activeCode != null) {
      final Path? activePath = geometry.visualRegions[activeCode];
      if (activePath != null) {
        final bool selected = selectedCode == activeCode;
        canvas.drawPath(
          activePath,
          Paint()
            ..style = PaintingStyle.fill
            ..color = colorScheme.primary.withValues(
              alpha: selected ? 0.30 : 0.20,
            ),
        );
        canvas.drawPath(
          activePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * (selected ? 0.011 : 0.008)
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = colorScheme.primary.withValues(
              alpha: selected ? 0.95 : 0.74,
            ),
        );
      }
    }
  }

  void _paintFace(Canvas canvas, Size size, Color outline) {
    final double cx = size.width * 0.5;
    final Paint featurePaint = Paint()
      ..color = outline.withValues(alpha: 0.72)
      ..strokeWidth = size.width * 0.006
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cx - size.width * 0.032, size.height * 0.091),
      Offset(cx - size.width * 0.012, size.height * 0.091),
      featurePaint,
    );
    canvas.drawLine(
      Offset(cx + size.width * 0.012, size.height * 0.091),
      Offset(cx + size.width * 0.032, size.height * 0.091),
      featurePaint,
    );
    canvas.drawLine(
      Offset(cx, size.height * 0.097),
      Offset(cx - size.width * 0.005, size.height * 0.119),
      featurePaint..strokeWidth = size.width * 0.004,
    );
    canvas.drawLine(
      Offset(cx - size.width * 0.019, size.height * 0.134),
      Offset(cx + size.width * 0.019, size.height * 0.134),
      featurePaint,
    );
  }

  void _paintMeasurementBands(Canvas canvas, Size size) {
    final Paint bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.009
      ..strokeCap = StrokeCap.round
      ..color = colorScheme.primary.withValues(alpha: 0.72);

    for (final Path path in geometry.measurementBands) {
      canvas.drawPath(path, bandPaint);
    }
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

  late final Path head;
  late final Path neck;
  late final Path torso;
  late final Path tankTop;
  late final Path shorts;
  late final Path hair;
  late final Path neckShade;

  final List<Path> skinParts = <Path>[];
  final List<Path> measurementBands = <Path>[];
  final Map<String, Path> hitPaths = <String, Path>{};
  final Map<String, Path> visualRegions = <String, Path>{};

  double get w => size.width;
  double get h => size.height;
  double x(double value) => w * value;
  double y(double value) => h * value;

  Path _rectBand(double left, double top, double right, double bottom) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(left), y(top), x(right), y(bottom)),
          Radius.circular(w * 0.018),
        ),
      );
  }

  Path _limb({
    required bool left,
    required double topY,
    required double bottomY,
    required double innerTop,
    required double outerTop,
    required double innerBottom,
    required double outerBottom,
  }) {
    final double sign = left ? -1 : 1;
    double px(double distance) => x(0.5 + sign * distance);

    final Path path = Path()
      ..moveTo(px(innerTop), y(topY))
      ..cubicTo(
        px(innerTop + 0.012),
        y(topY + 0.10 * (bottomY - topY)),
        px(innerBottom - 0.006),
        y(bottomY - 0.10 * (bottomY - topY)),
        px(innerBottom),
        y(bottomY),
      )
      ..cubicTo(
        px(outerBottom + 0.010),
        y(bottomY + 0.006),
        px(outerBottom + 0.010),
        y(bottomY - 0.045 * (bottomY - topY)),
        px(outerBottom),
        y(bottomY - 0.005),
      )
      ..cubicTo(
        px(outerTop + 0.006),
        y(topY + 0.12 * (bottomY - topY)),
        px(outerTop),
        y(topY + 0.02),
        px(outerTop),
        y(topY),
      )
      ..close();

    return path;
  }

  Path _leg({
    required bool left,
    required double topY,
    required double kneeY,
    required double ankleY,
    required double innerTop,
    required double outerTop,
  }) {
    final double sign = left ? -1 : 1;
    double px(double distance) => x(0.5 + sign * distance);

    return Path()
      ..moveTo(px(innerTop), y(topY))
      ..cubicTo(
        px(innerTop + 0.005),
        y(topY + 0.08),
        px(0.047),
        y(kneeY - 0.025),
        px(0.046),
        y(kneeY),
      )
      ..cubicTo(
        px(0.047),
        y(kneeY + 0.08),
        px(0.055),
        y(ankleY - 0.035),
        px(0.049),
        y(ankleY),
      )
      ..lineTo(px(0.082), y(ankleY + 0.018))
      ..cubicTo(
        px(0.100),
        y(ankleY + 0.023),
        px(0.106),
        y(ankleY + 0.010),
        px(0.091),
        y(ankleY - 0.004),
      )
      ..cubicTo(
        px(0.096),
        y(kneeY + 0.07),
        px(outerTop + 0.012),
        y(topY + 0.08),
        px(outerTop),
        y(topY),
      )
      ..close();
  }

  void _register(String code, Path path) {
    hitPaths[code] = path;
    visualRegions[code] = path;
  }

  void _build() {
    head = Path()
      ..moveTo(x(0.445), y(0.047))
      ..cubicTo(x(0.455), y(0.018), x(0.545), y(0.018), x(0.555), y(0.047))
      ..cubicTo(x(0.570), y(0.080), x(0.558), y(0.143), x(0.526), y(0.160))
      ..cubicTo(x(0.510), y(0.169), x(0.490), y(0.169), x(0.474), y(0.160))
      ..cubicTo(x(0.442), y(0.143), x(0.430), y(0.080), x(0.445), y(0.047))
      ..close();

    hair = Path()
      ..moveTo(x(0.442), y(0.061))
      ..cubicTo(x(0.432), y(0.025), x(0.466), y(0.010), x(0.500), y(0.012))
      ..cubicTo(x(0.548), y(0.009), x(0.568), y(0.036), x(0.558), y(0.078))
      ..cubicTo(x(0.548), y(0.061), x(0.541), y(0.047), x(0.527), y(0.043))
      ..cubicTo(x(0.505), y(0.051), x(0.474), y(0.037), x(0.455), y(0.052))
      ..lineTo(x(0.445), y(0.084))
      ..close();

    neck = Path()
      ..moveTo(x(0.476), y(0.151))
      ..cubicTo(x(0.480), y(0.174), x(0.470), y(0.190), x(0.450), y(0.199))
      ..lineTo(x(0.550), y(0.199))
      ..cubicTo(x(0.530), y(0.190), x(0.520), y(0.174), x(0.524), y(0.151))
      ..close();

    neckShade = Path()
      ..moveTo(x(0.476), y(0.158))
      ..cubicTo(x(0.489), y(0.180), x(0.511), y(0.180), x(0.524), y(0.158))
      ..lineTo(x(0.524), y(0.177))
      ..cubicTo(x(0.510), y(0.195), x(0.490), y(0.195), x(0.476), y(0.177))
      ..close();

    torso = Path()
      ..moveTo(x(0.450), y(0.190))
      ..cubicTo(x(0.414), y(0.197), x(0.398), y(0.224), x(0.400), y(0.263))
      ..cubicTo(x(0.405), y(0.325), x(0.420), y(0.410), x(0.413), y(0.488))
      ..cubicTo(x(0.438), y(0.515), x(0.562), y(0.515), x(0.587), y(0.488))
      ..cubicTo(x(0.580), y(0.410), x(0.595), y(0.325), x(0.600), y(0.263))
      ..cubicTo(x(0.602), y(0.224), x(0.586), y(0.197), x(0.550), y(0.190))
      ..cubicTo(x(0.532), y(0.216), x(0.518), y(0.231), x(0.500), y(0.232))
      ..cubicTo(x(0.482), y(0.231), x(0.468), y(0.216), x(0.450), y(0.190))
      ..close();

    tankTop = Path()
      ..moveTo(x(0.450), y(0.190))
      ..cubicTo(x(0.462), y(0.226), x(0.477), y(0.248), x(0.500), y(0.251))
      ..cubicTo(x(0.523), y(0.248), x(0.538), y(0.226), x(0.550), y(0.190))
      ..lineTo(x(0.584), y(0.203))
      ..cubicTo(x(0.575), y(0.298), x(0.582), y(0.402), x(0.584), y(0.474))
      ..cubicTo(x(0.552), y(0.494), x(0.448), y(0.494), x(0.416), y(0.474))
      ..cubicTo(x(0.418), y(0.402), x(0.425), y(0.298), x(0.416), y(0.203))
      ..close();

    shorts = Path()
      ..moveTo(x(0.413), y(0.472))
      ..cubicTo(x(0.445), y(0.488), x(0.555), y(0.488), x(0.587), y(0.472))
      ..lineTo(x(0.598), y(0.585))
      ..cubicTo(x(0.565), y(0.599), x(0.535), y(0.599), x(0.500), y(0.576))
      ..cubicTo(x(0.465), y(0.599), x(0.435), y(0.599), x(0.402), y(0.585))
      ..close();

    final Path leftUpperArm = _limb(
      left: true,
      topY: 0.205,
      bottomY: 0.405,
      innerTop: 0.100,
      outerTop: 0.147,
      innerBottom: 0.126,
      outerBottom: 0.165,
    );
    final Path rightUpperArm = _limb(
      left: false,
      topY: 0.205,
      bottomY: 0.405,
      innerTop: 0.100,
      outerTop: 0.147,
      innerBottom: 0.126,
      outerBottom: 0.165,
    );
    final Path leftForearm = _limb(
      left: true,
      topY: 0.395,
      bottomY: 0.585,
      innerTop: 0.126,
      outerTop: 0.165,
      innerBottom: 0.145,
      outerBottom: 0.174,
    );
    final Path rightForearm = _limb(
      left: false,
      topY: 0.395,
      bottomY: 0.585,
      innerTop: 0.126,
      outerTop: 0.165,
      innerBottom: 0.145,
      outerBottom: 0.174,
    );

    final Path leftLeg = _leg(
      left: true,
      topY: 0.568,
      kneeY: 0.755,
      ankleY: 0.958,
      innerTop: 0.018,
      outerTop: 0.098,
    );
    final Path rightLeg = _leg(
      left: false,
      topY: 0.568,
      kneeY: 0.755,
      ankleY: 0.958,
      innerTop: 0.018,
      outerTop: 0.098,
    );

    skinParts
      ..add(head)
      ..add(neck)
      ..add(leftUpperArm)
      ..add(rightUpperArm)
      ..add(leftForearm)
      ..add(rightForearm)
      ..add(leftLeg)
      ..add(rightLeg);

    _register('neck_cm', _rectBand(0.462, 0.157, 0.538, 0.198));
    _register('shoulders_cm', _rectBand(0.401, 0.202, 0.599, 0.254));
    _register('chest_cm', _rectBand(0.412, 0.274, 0.588, 0.333));
    _register('waist_cm', _rectBand(0.420, 0.390, 0.580, 0.438));
    _register('abdomen_cm', _rectBand(0.416, 0.432, 0.584, 0.487));
    _register('hips_cm', _rectBand(0.405, 0.492, 0.595, 0.571));

    _register('left_arm_cm', leftUpperArm);
    _register('right_arm_cm', rightUpperArm);
    _register('left_forearm_cm', leftForearm);
    _register('right_forearm_cm', rightForearm);

    final Path leftThigh = _rectBand(0.394, 0.568, 0.492, 0.758);
    final Path rightThigh = _rectBand(0.508, 0.568, 0.606, 0.758);
    final Path leftCalf = _rectBand(0.405, 0.744, 0.489, 0.955);
    final Path rightCalf = _rectBand(0.511, 0.744, 0.595, 0.955);

    _register('left_thigh_cm', leftThigh);
    _register('right_thigh_cm', rightThigh);
    _register('left_calf_cm', leftCalf);
    _register('right_calf_cm', rightCalf);

    measurementBands
      ..add(
        Path()
          ..moveTo(x(0.415), y(0.302))
          ..lineTo(x(0.585), y(0.302)),
      )
      ..add(
        Path()
          ..moveTo(x(0.421), y(0.414))
          ..lineTo(x(0.579), y(0.414)),
      )
      ..add(
        Path()
          ..moveTo(x(0.410), y(0.515))
          ..lineTo(x(0.590), y(0.515)),
      );
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
