import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../features/bookings/booking_editor.dart';
import '../features/bookings/quick_add.dart';

/// Höhe der Navigationsleiste ohne Safe Area.
const kNavBarHeight = 68.0;

/// Abstand, den scrollbare Inhalte unten lassen müssen (Leiste + Safe Area).
double bottomContentPadding(BuildContext context) => kNavBarHeight + MediaQuery.paddingOf(context).bottom + 28;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(quickAddRequestProvider, (_, request) {
      if (request == null) return;
      ref.read(quickAddRequestProvider.notifier).clear();
      showBookingEditor(context, type: request.type, title: request.title, amount: request.amount);
    });

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _NavBar(
        index: shell.currentIndex,
        onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        onAdd: () => showBookingEditor(context),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect, required this.onAdd});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: kNavBarHeight + bottom + 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: kNavBarHeight + bottom,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: ZColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Color(0x14824A6E), blurRadius: 30, offset: Offset(0, -6), spreadRadius: -8),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Start',
                      selected: index == 0,
                      onTap: () => onSelect(0),
                    ),
                    _NavItem(
                      icon: Icons.donut_large_outlined,
                      activeIcon: Icons.donut_large_rounded,
                      label: 'Statistik',
                      selected: index == 1,
                      onTap: () => onSelect(1),
                    ),
                    const Expanded(child: SizedBox()),
                    _NavItem(
                      icon: Icons.savings_outlined,
                      activeIcon: Icons.savings_rounded,
                      label: 'Sparen',
                      selected: index == 2,
                      onTap: () => onSelect(2),
                    ),
                    _NavItem(
                      icon: Icons.tune_rounded,
                      activeIcon: Icons.tune_rounded,
                      label: 'Einstellungen',
                      selected: index == 3,
                      onTap: () => onSelect(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottom + kNavBarHeight - 40,
            child: _PlusButton(onTap: onAdd),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZColors.text : ZColors.textTertiary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          radius: 36,
          highlightColor: Colors.transparent,
          splashColor: ZColors.accentLight.withValues(alpha: 0.4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(selected ? activeIcon : icon, key: ValueKey(selected), color: color, size: 25),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: ZText.small.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 5 : 0,
                height: 5,
                decoration: const BoxDecoration(color: ZColors.accent, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusButton extends StatefulWidget {
  const _PlusButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Neue Buchung',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: ZColors.accentGradient,
              shape: BoxShape.circle,
              border: Border.all(color: ZColors.card, width: 5),
              boxShadow: [
                BoxShadow(
                  color: ZColors.accentDeep.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
          ),
        ),
      ),
    );
  }
}
