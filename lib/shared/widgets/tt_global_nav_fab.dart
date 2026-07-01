import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum TtFoodNavItem {
  none,
  settings,
  dashboard,
  menu,
}

class TtFoodBottomNavBar extends StatefulWidget {
  const TtFoodBottomNavBar({
    this.activeItem = TtFoodNavItem.dashboard,
    this.homeRoute = '/',
    this.alternateHubLabel = 'Allenamento',
    this.alternateHubRoute = '/workout',
    this.alternateHubIcon = Icons.fitness_center_rounded,
    this.alternateHubEnabled = false,
    this.alternateHubDisabledMessage =
        'Allenamento disabilitato in questa versione.',
    super.key,
  });

  final TtFoodNavItem activeItem;
  final String homeRoute;
  final String alternateHubLabel;
  final String alternateHubRoute;
  final IconData alternateHubIcon;
  final bool alternateHubEnabled;
  final String alternateHubDisabledMessage;

  @override
  State<TtFoodBottomNavBar> createState() => _TtFoodBottomNavBarState();
}

class _TtFoodBottomNavBarState extends State<TtFoodBottomNavBar> {
  OverlayEntry? _quickOverlay;
  int _quickBackgroundTaps = 0;
  bool _showQuickHint = false;

  bool get _quickOpen => _quickOverlay != null;

  @override
  void dispose() {
    _quickOverlay?.remove();
    _quickOverlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _NavSideButton(
                          tooltip: 'Profilo e impostazioni',
                          icon: Icons.manage_accounts_outlined,
                          isActive: widget.activeItem == TtFoodNavItem.settings,
                          onPressed: () => _go(context, '/settings'),
                        ),
                        const SizedBox(width: 92),
                        _NavSideButton(
                          tooltip: 'Scorciatoie',
                          icon: _quickOpen
                              ? Icons.close_rounded
                              : Icons.menu_rounded,
                          isActive: _quickOpen ||
                              widget.activeItem == TtFoodNavItem.menu,
                          onPressed: () => _toggleQuickOverlay(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: widget.activeItem == TtFoodNavItem.dashboard ? 18 : 8,
                child: _DashboardButton(
                  isActive: widget.activeItem == TtFoodNavItem.dashboard,
                  onPressed: () => _go(context, widget.homeRoute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    _removeQuickOverlay();
    context.go(route);
  }

  void _toggleQuickOverlay(BuildContext context) {
    if (_quickOpen) {
      _removeQuickOverlay();
      return;
    }
    _quickOverlay = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              bottom: 112,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleQuickBackgroundTap,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .scrim
                          .withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 34,
              bottom: 96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _QuickMenuDot(
                    label: 'Oggi',
                    icon: Icons.today_rounded,
                    onPressed: () => _go(context, '/food/days/${_today()}'),
                  ),
                  _QuickMenuDot(
                    label: 'Misure',
                    icon: Icons.monitor_weight_outlined,
                    onPressed: () => _go(context, '/measurements'),
                  ),
                  _QuickMenuDot(
                    label: 'Ricette',
                    icon: Icons.menu_book_rounded,
                    onPressed: () => _go(context, '/food/recipes'),
                  ),
                  _QuickMenuDot(
                    label: 'Alimenti',
                    icon: Icons.inventory_2_outlined,
                    onPressed: () => _go(context, '/food/ingredients'),
                  ),
                  _QuickMenuDot(
                    label: widget.alternateHubLabel,
                    icon: widget.alternateHubIcon,
                    onPressed: () {
                      if (widget.alternateHubEnabled) {
                        _go(context, widget.alternateHubRoute);
                      } else {
                        _removeQuickOverlay();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(widget.alternateHubDisabledMessage),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            if (_showQuickHint)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CustomPaint(
                        painter: _QuickHintArrowPainter(
                          color: Theme.of(overlayContext).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 112),
                        child: Center(
                          child: _QuickHintCard(
                            text: 'Perché non provi a premere questo pulsante?',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_quickOverlay!);
    setState(() {});
  }

  void _handleQuickBackgroundTap() {
    _quickBackgroundTaps += 1;
    if (_quickBackgroundTaps >= 5) {
      _showQuickHint = true;
    }
    _quickOverlay?.markNeedsBuild();
  }

  void _removeQuickOverlay() {
    _quickOverlay?.remove();
    _quickOverlay = null;
    _quickBackgroundTaps = 0;
    _showQuickHint = false;
    if (mounted) {
      setState(() {});
    }
  }

  String _today() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _QuickHintCard extends StatelessWidget {
  const _QuickHintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 14,
      shadowColor: colors.shadow.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🙂', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickHintArrowPainter extends CustomPainter {
  const _QuickHintArrowPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Parte dalla zona inferiore destra del messaggio.
    final Offset start = Offset(
      size.width * 0.62,
      size.height * 0.50,
    );

    // Termina poco sopra e a sinistra del pulsante X.
    final Offset end = Offset(
      size.width - 78,
      size.height - 96,
    );

    // Il primo controllo mantiene l'uscita iniziale quasi verticale.
    final Offset firstControl = Offset(
      start.dx,
      start.dy + size.height * 0.13,
    );

    // Il secondo controllo accompagna la curva verso destra e verso la X.
    final Offset secondControl = Offset(
      end.dx - size.width * 0.11,
      end.dy - size.height * 0.10,
    );

    final Paint arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final Path curve = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        firstControl.dx,
        firstControl.dy,
        secondControl.dx,
        secondControl.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(curve, arrowPaint);

    // La punta viene orientata usando la tangente finale della curva.
    final Offset tangent = end - secondControl;
    final double tangentLength = tangent.distance;

    if (tangentLength == 0) {
      return;
    }

    final Offset direction = tangent / tangentLength;
    final Offset perpendicular = Offset(
      -direction.dy,
      direction.dx,
    );

    const double headLength = 22;
    const double headWidth = 9;

    final Offset headBase = end - direction * headLength;
    final Offset headLeft = headBase + perpendicular * headWidth;
    final Offset headRight = headBase - perpendicular * headWidth;

    final Path arrowHead = Path()
      ..moveTo(headLeft.dx, headLeft.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(headRight.dx, headRight.dy);

    canvas.drawPath(arrowHead, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _QuickHintArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({
    required this.isActive,
    required this.onPressed,
  });

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 62,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor:
              isActive ? colors.primary : colors.secondaryContainer,
          foregroundColor:
              isActive ? colors.onPrimary : colors.onSecondaryContainer,
          elevation: isActive ? 6 : 0,
        ),
        onPressed: onPressed,
        child: const Icon(Icons.home_rounded),
      ),
    );
  }
}

class _NavSideButton extends StatelessWidget {
  const _NavSideButton({
    required this.tooltip,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? colors.primary : colors.secondaryContainer,
        foregroundColor:
            isActive ? colors.onPrimary : colors.onSecondaryContainer,
        minimumSize: const Size.square(48),
      ),
      icon: Icon(icon),
    );
  }
}

class _QuickMenuDot extends StatelessWidget {
  const _QuickMenuDot({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Material(
            color: colors.inverseSurface.withValues(alpha: 0.95),
            elevation: 8,
            shadowColor: colors.shadow.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: label,
            child: Material(
              color: colors.primary,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: colors.shadow.withValues(alpha: 0.22),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(icon, color: colors.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TtGlobalNavFab extends StatefulWidget {
  const TtGlobalNavFab({super.key});

  @override
  State<TtGlobalNavFab> createState() => _TtGlobalNavFabState();
}

class _TtGlobalNavFabState extends State<TtGlobalNavFab> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isOpen
              ? Column(
                  key: const ValueKey<String>('open'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _MiniNavFab(
                      tooltip: 'Oggi',
                      icon: Icons.today_rounded,
                      onPressed: () => _go(context, '/food/days/${_today()}'),
                    ),
                    _MiniNavFab(
                      tooltip: 'Misurazioni',
                      icon: Icons.monitor_weight_outlined,
                      onPressed: () => _go(context, '/measurements'),
                    ),
                    _MiniNavFab(
                      tooltip: 'Ricette',
                      icon: Icons.menu_book_rounded,
                      onPressed: () => _go(context, '/food/recipes'),
                    ),
                    _MiniNavFab(
                      tooltip: 'Allenamento in preparazione',
                      icon: Icons.fitness_center_rounded,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Allenamento disabilitato in questa versione.',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey<String>('closed')),
        ),
        FloatingActionButton(
          tooltip: _isOpen ? 'Chiudi scorciatoie' : 'Apri scorciatoie',
          onPressed: () => setState(() => _isOpen = !_isOpen),
          child: Icon(_isOpen ? Icons.close_rounded : Icons.menu_rounded),
        ),
      ],
    );
  }

  void _go(BuildContext context, String route) {
    setState(() => _isOpen = false);
    context.go(route);
  }

  String _today() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _MiniNavFab extends StatelessWidget {
  const _MiniNavFab({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton.small(
        heroTag: null,
        tooltip: tooltip,
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }
}
