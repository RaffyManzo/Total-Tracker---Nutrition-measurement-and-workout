import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
