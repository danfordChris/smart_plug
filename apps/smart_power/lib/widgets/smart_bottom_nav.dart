import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';

/// Bottom navigation — mirrors `BottomNav` in
/// `implementation_plan/mobile_design_docs/dashboard-widgets.jsx` (lines 140-171).
///
/// Five destinations: Home · Devices · [+ FAB] · Insights · Profile.
/// The centre destination is a circular FAB ("Add device") layered on top
/// of an invisible NavigationDestination so the M3 indicator + ripple still
/// work for the four real tabs.
class SmartBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAddDevice;

  const SmartBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onAddDevice,
  });

  static const double _height = 80;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NavigationBar(
              height: _height,
              selectedIndex: currentIndex,
              onDestinationSelected: (i) {
                if (i == 2) {
                  onAddDevice();
                  return;
                }
                onDestinationSelected(i);
              },
              destinations: [
                _dest(scheme, AppIcons.home, 'Home', currentIndex == 0),
                _dest(scheme, AppIcons.devices, 'Devices', currentIndex == 1),
                const NavigationDestination(
                  icon: SizedBox(width: 24, height: 24),
                  label: '',
                ),
                _dest(scheme, AppIcons.insights, 'Insights', currentIndex == 3),
                _dest(scheme, AppIcons.profile, 'Profile', currentIndex == 4),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              top: -10,
              child: Center(
                child: Tooltip(
                  message: 'Add device',
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: FloatingActionButton(
                      heroTag: 'add-device-fab',
                      onPressed: onAddDevice,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.fab),
                      ),
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      elevation: 3,
                      child: HugeIcon(
                        icon: AppIcons.add,
                        size: 22,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(
    ColorScheme scheme,
    dynamic icon,
    String label,
    bool selected,
  ) {
    return NavigationDestination(
      icon: HugeIcon(icon: icon, size: 22, color: scheme.onSurfaceVariant),
      selectedIcon: HugeIcon(icon: icon, size: 22, color: scheme.onSurface),
      label: label,
    );
  }
}

/// Section header — title + optional trailing link / value.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final bool trailingIsMono;
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.trailingIsMono = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    color: scheme.onSurface,
                  ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: trailingIsMono
                    ? AppTheme.monoStyle(scheme)
                    : Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
              ),
            ),
        ],
      ),
    );
  }
}
