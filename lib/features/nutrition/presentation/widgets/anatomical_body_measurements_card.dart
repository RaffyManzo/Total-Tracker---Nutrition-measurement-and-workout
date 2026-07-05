import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Interactive front-view male body used by the measurements hub.
///
/// The public API intentionally matches the previous widget so this file can
/// replace the existing implementation without changing any caller.
class AnatomicalBodyMeasurementsCard extends StatefulWidget {
  const AnatomicalBodyMeasurementsCard({
    required this.values,
    this.onRegionTap,
    this.onTapRegion,
    super.key,
  }) : assert(onRegionTap != null || onTapRegion != null);

  final Map<String, double?> values;
  final ValueChanged<String>? onRegionTap;

  /// Backwards-compatible alias retained for older callers and tests.
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

    // Small horizontal torso regions are evaluated first. Limbs come later,
    // avoiding accidental arm selection near shoulders and hips.
    for (final _BodyRegion region in _hitOrder) {
      if (geometry.hitPaths[region.code]?.contains(position) ?? false) {
        return region.code;
      }
    }
    return null;
  }

  void _selectRegion(String code) {
    if (_selectedCode != code) {
      setState(() => _selectedCode = code);
    }
    (widget.onRegionTap ?? widget.onTapRegion)?.call(code);
  }

  void _setHoveredRegion(String? code) {
    if (_hoveredCode == code) {
      return;
    }
    setState(() => _hoveredCode = code);
  }

  String _valueText(String code) {
    final double? value = widget.values[code];
    if (value == null || !value.isFinite || value <= 0) {
      return 'Nessuna misura';
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
      hint: 'Tocca una parte del corpo per inserire o aggiornare la misura.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.74),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.055),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CardHeader(colors: colors),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool useWideLayout = constraints.maxWidth >= 720;
                final double figureWidth = useWideLayout
                    ? (constraints.maxWidth * 0.48)
                        .clamp(310.0, 410.0)
                        .toDouble()
                    : constraints.maxWidth
                        .clamp(230.0, 360.0)
                        .toDouble();
                final Size figureSize = Size(
                  figureWidth,
                  figureWidth / _BodyGeometry.aspectRatio,
                );

                final Widget figure = _buildInteractiveFigure(
                  size: figureSize,
                  colors: colors,
                );

                final Widget details = _MeasurementDetails(
                  activeRegion: activeRegion,
                  selectedCode: _selectedCode,
                  valueText: _valueText,
                  onSelect: _selectRegion,
                );

                if (useWideLayout) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(child: Center(child: figure)),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: (constraints.maxWidth * 0.42)
                            .clamp(280.0, 370.0)
                            .toDouble(),
                        child: details,
                      ),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    Center(child: figure),
                    const SizedBox(height: 12),
                    details,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveFigure({
    required Size size,
    required ColorScheme colors,
  }) {
    final _BodyGeometry geometry = _geometryFor(size);

    return SizedBox.fromSize(
      size: size,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (PointerHoverEvent event) {
          _setHoveredRegion(_hitTest(event.localPosition, size));
        },
        onExit: (_) => _setHoveredRegion(null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (TapUpDetails details) {
            final String? code = _hitTest(details.localPosition, size);
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
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
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
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tocca direttamente collo, torace, vita, arti o fianchi.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeasurementDetails extends StatelessWidget {
  const _MeasurementDetails({
    required this.activeRegion,
    required this.selectedCode,
    required this.valueText,
    required this.onSelect,
  });

  final _BodyRegion? activeRegion;
  final String? selectedCode;
  final String Function(String code) valueText;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: activeRegion == null
                ? colors.surfaceContainerHighest
                : colors.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: activeRegion == null
                  ? colors.outlineVariant
                  : colors.primary.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: activeRegion == null ? colors.outline : colors.primary,
                  shape: BoxShape.circle,
                  boxShadow: activeRegion == null
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.26),
                            blurRadius: 8,
                          ),
                        ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: activeRegion == null
                    ? Text(
                        'Seleziona una zona sulla figura.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            activeRegion!.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            valueText(activeRegion!.code),
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
        const SizedBox(height: 10),
        Text(
          'Zone disponibili',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 340 ? 3 : 2;
            final double gap = 6;
            final double itemWidth =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final _BodyRegion region in _regions)
                  SizedBox(
                    width: itemWidth,
                    child: _RegionButton(
                      region: region,
                      value: valueText(region.code),
                      selected: selectedCode == region.code,
                      onTap: () => onSelect(region.code),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RegionButton extends StatelessWidget {
  const _RegionButton({
    required this.region,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final _BodyRegion region;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool hasValue = value != 'Nessuna misura';

    return Semantics(
      button: true,
      selected: selected,
      label: '${region.label}, $value',
      child: Material(
        color: selected
            ? colors.primaryContainer
            : colors.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? colors.primary.withValues(alpha: 0.46)
                    : colors.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  region.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  hasValue ? value : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer.withValues(alpha: 0.82)
                        : colors.onSurfaceVariant,
                    fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
    final _BodyPalette palette = _BodyPalette(colorScheme);

    _paintStage(canvas, size, palette);
    _paintBodyShadow(canvas, size, palette);

    // Back-to-front ordering produces a continuous silhouette without visible
    // seams where limbs meet the torso.
    _paintSkinPath(canvas, geometry.leftLeg, palette, size);
    _paintSkinPath(canvas, geometry.rightLeg, palette, size);
    _paintSkinPath(canvas, geometry.leftArm, palette, size);
    _paintSkinPath(canvas, geometry.rightArm, palette, size);
    _paintSkinPath(canvas, geometry.torso, palette, size);
    _paintSkinPath(canvas, geometry.neck, palette, size);
    _paintSkinPath(canvas, geometry.head, palette, size);

    _paintShorts(canvas, size, palette);
    _paintHair(canvas, size, palette);
    _paintAnatomicalDetails(canvas, size, palette);
    _paintMeasurementBands(canvas, size, palette);
    _paintActiveRegion(canvas, size, palette);
  }

  void _paintStage(Canvas canvas, Size size, _BodyPalette palette) {
    final RRect background = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.075),
    );

    canvas.drawRRect(
      background,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.stageTop,
            palette.stageBottom,
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.51),
        width: size.width * 0.76,
        height: size.height * 0.91,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.halo,
            palette.halo.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.51),
            width: size.width * 0.78,
            height: size.height * 0.92,
          ),
        ),
    );
  }

  void _paintBodyShadow(Canvas canvas, Size size, _BodyPalette palette) {
    final Path combined = Path.combine(
      PathOperation.union,
      Path.combine(
        PathOperation.union,
        geometry.leftLeg,
        geometry.rightLeg,
      ),
      Path.combine(
        PathOperation.union,
        Path.combine(
          PathOperation.union,
          geometry.leftArm,
          geometry.rightArm,
        ),
        Path.combine(
          PathOperation.union,
          geometry.torso,
          Path.combine(
            PathOperation.union,
            geometry.neck,
            geometry.head,
          ),
        ),
      ),
    );

    canvas.save();
    canvas.translate(0, size.width * 0.012);
    canvas.drawPath(
      combined,
      Paint()
        ..color = palette.shadow
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.width * 0.022,
        ),
    );
    canvas.restore();
  }

  void _paintSkinPath(
    Canvas canvas,
    Path path,
    _BodyPalette palette,
    Size size,
  ) {
    final Rect bounds = path.getBounds();
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          palette.skinLight,
          palette.skin,
          palette.skinShade,
        ],
        stops: const <double>[0, 0.57, 1],
      ).createShader(bounds);

    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.0052
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = palette.outline,
    );
  }

  void _paintShorts(Canvas canvas, Size size, _BodyPalette palette) {
    final Rect bounds = geometry.shorts.getBounds();
    canvas.drawPath(
      geometry.shorts,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.shortsLight,
            palette.shorts,
            palette.shortsDark,
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      geometry.shorts,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.006
        ..strokeJoin = StrokeJoin.round
        ..color = palette.shortsOutline,
    );

    final Paint seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.004
      ..strokeCap = StrokeCap.round
      ..color = palette.shortsOutline.withValues(alpha: 0.62);

    canvas.drawPath(geometry.waistband, seam);
    canvas.drawPath(geometry.shortCenterSeam, seam);
  }

  void _paintHair(Canvas canvas, Size size, _BodyPalette palette) {
    canvas.drawPath(
      geometry.hair,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.hairLight, palette.hair],
        ).createShader(geometry.hair.getBounds()),
    );

    canvas.drawPath(
      geometry.hair,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.004
        ..strokeJoin = StrokeJoin.round
        ..color = palette.hair.withValues(alpha: 0.86),
    );
  }

  void _paintAnatomicalDetails(
    Canvas canvas,
    Size size,
    _BodyPalette palette,
  ) {
    final Paint detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.0044
      ..color = palette.detail;

    final double cx = size.width * 0.5;

    // Eyes, nose and mouth remain deliberately subtle so the silhouette stays
    // clean at small phone sizes.
    canvas.drawLine(
      Offset(cx - size.width * 0.031, size.height * 0.091),
      Offset(cx - size.width * 0.012, size.height * 0.091),
      detail,
    );
    canvas.drawLine(
      Offset(cx + size.width * 0.012, size.height * 0.091),
      Offset(cx + size.width * 0.031, size.height * 0.091),
      detail,
    );
    canvas.drawLine(
      Offset(cx, size.height * 0.097),
      Offset(cx - size.width * 0.004, size.height * 0.119),
      detail..strokeWidth = size.width * 0.0034,
    );
    canvas.drawLine(
      Offset(cx - size.width * 0.018, size.height * 0.135),
      Offset(cx + size.width * 0.018, size.height * 0.135),
      detail,
    );

    canvas.drawPath(geometry.clavicles, detail);
    canvas.drawPath(geometry.pectoralLine, detail);
    canvas.drawPath(geometry.abdominalLine, detail);

    canvas.drawCircle(
      Offset(cx, size.height * 0.435),
      size.width * 0.006,
      Paint()..color = palette.detail.withValues(alpha: 0.68),
    );
  }

  void _paintMeasurementBands(
    Canvas canvas,
    Size size,
    _BodyPalette palette,
  ) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.0065
      ..strokeCap = StrokeCap.round
      ..color = palette.measurementBand;

    for (final Path path in geometry.measurementBands) {
      _drawDashedPath(
        canvas,
        path,
        paint,
        dashLength: size.width * 0.025,
        gapLength: size.width * 0.018,
      );
    }
  }

  void _paintActiveRegion(
    Canvas canvas,
    Size size,
    _BodyPalette palette,
  ) {
    final String? activeCode = hoveredCode ?? selectedCode;
    if (activeCode == null) {
      return;
    }

    final Path? activePath = geometry.visualRegions[activeCode];
    if (activePath == null) {
      return;
    }

    final bool selected = selectedCode == activeCode;
    final double alpha = selected ? 0.34 : 0.22;

    canvas.drawPath(
      activePath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = colorScheme.primary.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          selected ? size.width * 0.012 : size.width * 0.006,
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
          alpha: selected ? 0.98 : 0.78,
        ),
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next =
            (distance + dashLength).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
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

class _BodyPalette {
  _BodyPalette(ColorScheme colors)
      : stageTop = Color.alphaBlend(
          colors.primary.withValues(alpha: 0.035),
          colors.surfaceContainerLowest,
        ),
        stageBottom = Color.alphaBlend(
          colors.tertiary.withValues(alpha: 0.045),
          colors.surfaceContainerHigh,
        ),
        halo = colors.primary.withValues(alpha: 0.075),
        shadow = colors.shadow.withValues(alpha: 0.16),
        skinLight = Color.alphaBlend(
          colors.tertiary.withValues(alpha: 0.055),
          const Color(0xFFFFC2AF),
        ),
        skin = Color.alphaBlend(
          colors.tertiary.withValues(alpha: 0.075),
          const Color(0xFFFFA58F),
        ),
        skinShade = Color.alphaBlend(
          colors.primary.withValues(alpha: 0.065),
          const Color(0xFFE47F70),
        ),
        outline = Color.alphaBlend(
          colors.onSurface.withValues(alpha: 0.40),
          const Color(0xFF9D574F),
        ),
        detail = Color.alphaBlend(
          colors.onSurface.withValues(alpha: 0.46),
          const Color(0xFF8D504A),
        ),
        hair = const Color(0xFF20191B),
        hairLight = const Color(0xFF3A292D),
        shortsLight = Color.alphaBlend(
          colors.primary.withValues(alpha: 0.12),
          const Color(0xFF9E4B5A),
        ),
        shorts = Color.alphaBlend(
          colors.primary.withValues(alpha: 0.18),
          const Color(0xFF7C3445),
        ),
        shortsDark = Color.alphaBlend(
          colors.secondary.withValues(alpha: 0.12),
          const Color(0xFF5D2635),
        ),
        shortsOutline = Color.alphaBlend(
          colors.onSurface.withValues(alpha: 0.30),
          const Color(0xFF4E1E2B),
        ),
        measurementBand = Color.alphaBlend(
          colors.primary.withValues(alpha: 0.74),
          const Color(0xFF7E3443),
        );

  final Color stageTop;
  final Color stageBottom;
  final Color halo;
  final Color shadow;
  final Color skinLight;
  final Color skin;
  final Color skinShade;
  final Color outline;
  final Color detail;
  final Color hair;
  final Color hairLight;
  final Color shortsLight;
  final Color shorts;
  final Color shortsDark;
  final Color shortsOutline;
  final Color measurementBand;
}

class _BodyGeometry {
  _BodyGeometry(this.size) {
    _build();
  }

  static const double aspectRatio = 0.63;

  final Size size;

  late final Path head;
  late final Path neck;
  late final Path torso;
  late final Path shorts;
  late final Path hair;
  late final Path leftArm;
  late final Path rightArm;
  late final Path leftLeg;
  late final Path rightLeg;
  late final Path waistband;
  late final Path shortCenterSeam;
  late final Path clavicles;
  late final Path pectoralLine;
  late final Path abdominalLine;

  final List<Path> measurementBands = <Path>[];
  final Map<String, Path> hitPaths = <String, Path>{};
  final Map<String, Path> visualRegions = <String, Path>{};

  double get w => size.width;
  double get h => size.height;
  double x(double value) => w * value;
  double y(double value) => h * value;

  Path _roundedBand(double left, double top, double right, double bottom) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(left), y(top), x(right), y(bottom)),
          Radius.circular(w * 0.02),
        ),
      );
  }

  Path _horizontalCurve({
    required double left,
    required double right,
    required double top,
    double curve = 0,
  }) {
    return Path()
      ..moveTo(x(left), y(top))
      ..quadraticBezierTo(
        x((left + right) / 2),
        y(top + curve),
        x(right),
        y(top),
      );
  }

  Path _intersection(Path a, Path b) {
    return Path.combine(PathOperation.intersect, a, b);
  }

  Path _union(Path a, Path b) {
    return Path.combine(PathOperation.union, a, b);
  }

  void _register(String code, Path hitPath, {Path? visualPath}) {
    hitPaths[code] = hitPath;
    visualRegions[code] = visualPath ?? hitPath;
  }

  void _build() {
    _buildHeadAndTorso();
    _buildArms();
    _buildLegs();
    _buildShorts();
    _buildDetails();
    _buildInteractiveRegions();
    _buildMeasurementBands();
  }

  void _buildHeadAndTorso() {
    head = Path()
      ..moveTo(x(0.446), y(0.052))
      ..cubicTo(x(0.452), y(0.021), x(0.476), y(0.012), x(0.500), y(0.012))
      ..cubicTo(x(0.524), y(0.012), x(0.548), y(0.021), x(0.554), y(0.052))
      ..cubicTo(x(0.567), y(0.088), x(0.557), y(0.137), x(0.529), y(0.158))
      ..cubicTo(x(0.513), y(0.171), x(0.487), y(0.171), x(0.471), y(0.158))
      ..cubicTo(x(0.443), y(0.137), x(0.433), y(0.088), x(0.446), y(0.052))
      ..close();

    hair = Path()
      ..moveTo(x(0.438), y(0.067))
      ..cubicTo(x(0.426), y(0.031), x(0.448), y(0.012), x(0.478), y(0.009))
      ..cubicTo(x(0.506), y(0.001), x(0.543), y(0.011), x(0.558), y(0.034))
      ..cubicTo(x(0.569), y(0.051), x(0.566), y(0.077), x(0.559), y(0.094))
      ..lineTo(x(0.548), y(0.071))
      ..cubicTo(x(0.534), y(0.063), x(0.529), y(0.048), x(0.514), y(0.045))
      ..cubicTo(x(0.490), y(0.056), x(0.467), y(0.039), x(0.449), y(0.057))
      ..lineTo(x(0.442), y(0.092))
      ..close();

    neck = Path()
      ..moveTo(x(0.477), y(0.154))
      ..cubicTo(x(0.480), y(0.178), x(0.470), y(0.193), x(0.450), y(0.203))
      ..cubicTo(x(0.468), y(0.220), x(0.532), y(0.220), x(0.550), y(0.203))
      ..cubicTo(x(0.530), y(0.193), x(0.520), y(0.178), x(0.523), y(0.154))
      ..close();

    torso = Path()
      ..moveTo(x(0.451), y(0.194))
      ..cubicTo(x(0.419), y(0.198), x(0.387), y(0.214), x(0.357), y(0.241))
      ..cubicTo(x(0.370), y(0.282), x(0.392), y(0.323), x(0.401), y(0.365))
      ..cubicTo(x(0.411), y(0.413), x(0.405), y(0.462), x(0.387), y(0.510))
      ..cubicTo(x(0.416), y(0.548), x(0.584), y(0.548), x(0.613), y(0.510))
      ..cubicTo(x(0.595), y(0.462), x(0.589), y(0.413), x(0.599), y(0.365))
      ..cubicTo(x(0.608), y(0.323), x(0.630), y(0.282), x(0.643), y(0.241))
      ..cubicTo(x(0.613), y(0.214), x(0.581), y(0.198), x(0.549), y(0.194))
      ..cubicTo(x(0.537), y(0.223), x(0.520), y(0.240), x(0.500), y(0.242))
      ..cubicTo(x(0.480), y(0.240), x(0.463), y(0.223), x(0.451), y(0.194))
      ..close();
  }

  void _buildArms() {
    leftArm = Path()
      ..moveTo(x(0.367), y(0.229))
      ..cubicTo(x(0.324), y(0.235), x(0.300), y(0.266), x(0.292), y(0.309))
      ..cubicTo(x(0.280), y(0.374), x(0.276), y(0.436), x(0.260), y(0.494))
      ..cubicTo(x(0.248), y(0.540), x(0.236), y(0.579), x(0.242), y(0.610))
      ..cubicTo(x(0.245), y(0.631), x(0.257), y(0.649), x(0.272), y(0.656))
      ..cubicTo(x(0.284), y(0.662), x(0.292), y(0.650), x(0.287), y(0.638))
      ..cubicTo(x(0.305), y(0.651), x(0.316), y(0.636), x(0.307), y(0.622))
      ..cubicTo(x(0.300), y(0.610), x(0.292), y(0.594), x(0.297), y(0.573))
      ..cubicTo(x(0.312), y(0.509), x(0.329), y(0.449), x(0.343), y(0.392))
      ..cubicTo(x(0.356), y(0.339), x(0.375), y(0.286), x(0.394), y(0.250))
      ..cubicTo(x(0.394), y(0.238), x(0.382), y(0.229), x(0.367), y(0.229))
      ..close();

    rightArm = _mirrorPath(leftArm);
  }

  void _buildLegs() {
    leftLeg = Path()
      ..moveTo(x(0.402), y(0.535))
      ..cubicTo(x(0.395), y(0.596), x(0.397), y(0.668), x(0.407), y(0.727))
      ..cubicTo(x(0.413), y(0.769), x(0.405), y(0.817), x(0.397), y(0.864))
      ..cubicTo(x(0.389), y(0.911), x(0.386), y(0.954), x(0.393), y(0.977))
      ..cubicTo(x(0.400), y(0.995), x(0.427), y(1.000), x(0.448), y(0.991))
      ..cubicTo(x(0.460), y(0.985), x(0.455), y(0.972), x(0.442), y(0.969))
      ..cubicTo(x(0.452), y(0.927), x(0.463), y(0.878), x(0.463), y(0.832))
      ..cubicTo(x(0.463), y(0.783), x(0.455), y(0.743), x(0.461), y(0.695))
      ..cubicTo(x(0.468), y(0.636), x(0.481), y(0.584), x(0.493), y(0.548))
      ..cubicTo(x(0.468), y(0.536), x(0.430), y(0.531), x(0.402), y(0.535))
      ..close();

    rightLeg = _mirrorPath(leftLeg);
  }

  void _buildShorts() {
    shorts = Path()
      ..moveTo(x(0.388), y(0.496))
      ..cubicTo(x(0.422), y(0.511), x(0.578), y(0.511), x(0.612), y(0.496))
      ..lineTo(x(0.625), y(0.596))
      ..cubicTo(x(0.596), y(0.606), x(0.553), y(0.604), x(0.500), y(0.580))
      ..cubicTo(x(0.447), y(0.604), x(0.404), y(0.606), x(0.375), y(0.596))
      ..close();

    waistband = _horizontalCurve(
      left: 0.391,
      right: 0.609,
      top: 0.515,
      curve: 0.006,
    );

    shortCenterSeam = Path()
      ..moveTo(x(0.500), y(0.515))
      ..quadraticBezierTo(x(0.500), y(0.554), x(0.500), y(0.580));
  }

  void _buildDetails() {
    clavicles = Path()
      ..moveTo(x(0.425), y(0.235))
      ..quadraticBezierTo(x(0.466), y(0.248), x(0.491), y(0.254))
      ..moveTo(x(0.509), y(0.254))
      ..quadraticBezierTo(x(0.534), y(0.248), x(0.575), y(0.235));

    pectoralLine = Path()
      ..moveTo(x(0.418), y(0.318))
      ..quadraticBezierTo(x(0.457), y(0.329), x(0.492), y(0.321))
      ..moveTo(x(0.508), y(0.321))
      ..quadraticBezierTo(x(0.543), y(0.329), x(0.582), y(0.318));

    abdominalLine = Path()
      ..moveTo(x(0.500), y(0.341))
      ..cubicTo(x(0.496), y(0.385), x(0.496), y(0.432), x(0.500), y(0.469));
  }

  void _buildInteractiveRegions() {
    final Path bodyUpper = _union(torso, _union(leftArm, rightArm));
    final Path bodyLower = _union(torso, shorts);

    _register(
      'neck_cm',
      _intersection(neck, _roundedBand(0.451, 0.155, 0.549, 0.212)),
    );
    _register(
      'shoulders_cm',
      _intersection(bodyUpper, _roundedBand(0.330, 0.205, 0.670, 0.275)),
    );
    _register(
      'chest_cm',
      _intersection(torso, _roundedBand(0.365, 0.272, 0.635, 0.345)),
    );
    _register(
      'waist_cm',
      _intersection(torso, _roundedBand(0.388, 0.383, 0.612, 0.432)),
    );
    _register(
      'abdomen_cm',
      _intersection(torso, _roundedBand(0.380, 0.425, 0.620, 0.490)),
    );
    _register(
      'hips_cm',
      _intersection(bodyLower, _roundedBand(0.365, 0.486, 0.635, 0.572)),
    );

    _register(
      'left_arm_cm',
      _intersection(leftArm, _roundedBand(0.270, 0.220, 0.400, 0.415)),
    );
    _register(
      'right_arm_cm',
      _intersection(rightArm, _roundedBand(0.600, 0.220, 0.730, 0.415)),
    );
    _register(
      'left_forearm_cm',
      _intersection(leftArm, _roundedBand(0.230, 0.390, 0.345, 0.660)),
    );
    _register(
      'right_forearm_cm',
      _intersection(rightArm, _roundedBand(0.655, 0.390, 0.770, 0.660)),
    );

    _register(
      'left_thigh_cm',
      _intersection(leftLeg, _roundedBand(0.382, 0.535, 0.500, 0.750)),
    );
    _register(
      'right_thigh_cm',
      _intersection(rightLeg, _roundedBand(0.500, 0.535, 0.618, 0.750)),
    );
    _register(
      'left_calf_cm',
      _intersection(leftLeg, _roundedBand(0.375, 0.735, 0.475, 0.965)),
    );
    _register(
      'right_calf_cm',
      _intersection(rightLeg, _roundedBand(0.525, 0.735, 0.625, 0.965)),
    );
  }

  void _buildMeasurementBands() {
    measurementBands
      ..add(
        _horizontalCurve(
          left: 0.458,
          right: 0.542,
          top: 0.186,
          curve: 0.003,
        ),
      )
      ..add(
        _horizontalCurve(
          left: 0.382,
          right: 0.618,
          top: 0.304,
          curve: 0.006,
        ),
      )
      ..add(
        _horizontalCurve(
          left: 0.399,
          right: 0.601,
          top: 0.408,
          curve: 0.004,
        ),
      )
      ..add(
        _horizontalCurve(
          left: 0.380,
          right: 0.620,
          top: 0.528,
          curve: 0.006,
        ),
      );
  }

  Path _mirrorPath(Path original) {
    final Matrix4 matrix = Matrix4.identity()
      ..setEntry(0, 0, -1)
      ..setEntry(0, 3, w);
    return original.transform(matrix.storage);
  }
}

class _BodyRegion {
  const _BodyRegion(this.code, this.label, this.shortLabel);

  final String code;
  final String label;
  final String shortLabel;
}

const List<_BodyRegion> _regions = <_BodyRegion>[
  _BodyRegion('neck_cm', 'Collo', 'Collo'),
  _BodyRegion('shoulders_cm', 'Spalle', 'Spalle'),
  _BodyRegion('chest_cm', 'Torace', 'Torace'),
  _BodyRegion('waist_cm', 'Vita', 'Vita'),
  _BodyRegion('abdomen_cm', 'Addome', 'Addome'),
  _BodyRegion('hips_cm', 'Fianchi', 'Fianchi'),
  _BodyRegion('left_arm_cm', 'Braccio sinistro', 'Braccio S'),
  _BodyRegion('right_arm_cm', 'Braccio destro', 'Braccio D'),
  _BodyRegion('left_forearm_cm', 'Avambraccio sinistro', 'Avam. S'),
  _BodyRegion('right_forearm_cm', 'Avambraccio destro', 'Avam. D'),
  _BodyRegion('left_thigh_cm', 'Coscia sinistra', 'Coscia S'),
  _BodyRegion('right_thigh_cm', 'Coscia destra', 'Coscia D'),
  _BodyRegion('left_calf_cm', 'Polpaccio sinistro', 'Polpaccio S'),
  _BodyRegion('right_calf_cm', 'Polpaccio destro', 'Polpaccio D'),
];

const List<_BodyRegion> _hitOrder = <_BodyRegion>[
  _BodyRegion('neck_cm', 'Collo', 'Collo'),
  _BodyRegion('shoulders_cm', 'Spalle', 'Spalle'),
  _BodyRegion('chest_cm', 'Torace', 'Torace'),
  _BodyRegion('waist_cm', 'Vita', 'Vita'),
  _BodyRegion('abdomen_cm', 'Addome', 'Addome'),
  _BodyRegion('hips_cm', 'Fianchi', 'Fianchi'),
  _BodyRegion('left_arm_cm', 'Braccio sinistro', 'Braccio S'),
  _BodyRegion('right_arm_cm', 'Braccio destro', 'Braccio D'),
  _BodyRegion('left_forearm_cm', 'Avambraccio sinistro', 'Avam. S'),
  _BodyRegion('right_forearm_cm', 'Avambraccio destro', 'Avam. D'),
  _BodyRegion('left_thigh_cm', 'Coscia sinistra', 'Coscia S'),
  _BodyRegion('right_thigh_cm', 'Coscia destra', 'Coscia D'),
  _BodyRegion('left_calf_cm', 'Polpaccio sinistro', 'Polpaccio S'),
  _BodyRegion('right_calf_cm', 'Polpaccio destro', 'Polpaccio D'),
];

final Map<String, _BodyRegion> _regionsByCode =
    Map<String, _BodyRegion>.unmodifiable(
  <String, _BodyRegion>{
    for (final _BodyRegion region in _regions) region.code: region,
  },
);
