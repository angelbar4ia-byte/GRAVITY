library;

import 'package:flutter/material.dart';

import '../datos/modelos.dart';

/// Selector de menú; si solo hay uno, no se muestra.
class SelectorMenu extends StatelessWidget {
  const SelectorMenu({super.key, required this.menus, required this.actual, required this.alElegir});
  final List<MenuId> menus;
  final MenuId actual;
  final void Function(MenuId) alElegir;

  @override
  Widget build(BuildContext context) {
    if (menus.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SegmentedButton<MenuId>(
        showSelectedIcon: true,
        segments: [
          for (final m in menus)
            ButtonSegment(value: m, label: Text(m == MenuId.papa ? 'Papá' : 'Pareja y dueño')),
        ],
        selected: {actual},
        onSelectionChanged: (s) => alElegir(s.first),
      ),
    );
  }
}
