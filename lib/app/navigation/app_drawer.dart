import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell_config.dart';
import 'package:secondary_sales/app/navigation/menu_catalog.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

import 'package:secondary_sales/app/navigation/app_shell.dart';
import 'package:secondary_sales/features/settings/screens/settings_tab.dart';

/// Global navigation drawer, rendered from [visibleMenuSections].
///
/// A destination that is a shell tab is switched via [onSelectTab] (the shell's
/// `_setIndex`); a standalone destination is pushed. The drawer is presentation
/// only — it does not own navigation policy, so back-stack behavior stays with
/// the shell.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.moduleType,
    required this.currentShellIndex,
    required this.onSelectTab,
    this.onExitModule,
  });

  final String moduleType;
  final int currentShellIndex;
  final ValueChanged<int> onSelectTab;

  /// Returns to the module picker. Surfaced in the drawer footer so the
  /// capability the Dashboard back-arrow used to provide is preserved.
  final VoidCallback? onExitModule;

  void _open(BuildContext context, MenuDestination dest) {
    Navigator.of(context).pop(); // close the drawer first
    if (dest.builder != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: dest.builder!));
    } else if (dest.isTab && dest.shellIndex != null) {
      onSelectTab(dest.shellIndex!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sections = visibleMenuSections(moduleType, auth);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          _DrawerHeader(
            moduleType: moduleType,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                for (final section in sections) ...[
                  _SectionLabel(section.title),
                  for (final dest in section.items)
                    _MenuTile(
                      icon: dest.icon,
                      label: dest.label,
                      selected: dest.isTab && dest.shellIndex == currentShellIndex,
                      onTap: () => _open(context, dest),
                    ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderMuted),
          if (onExitModule != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MenuTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Switch Module',
                onTap: () {
                  Navigator.of(context).pop();
                  onExitModule!();
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child: _MenuTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              iconColor: Colors.red.shade600,
              textColor: Colors.red.shade700,
              onTap: () async {
                Navigator.of(context).pop();
                await context.read<AuthProvider>().logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.moduleType});

  final String moduleType;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final name = user?.employeeName ?? user?.name ?? 'User';
    final role = user?.role ?? '';
    final moduleLabel =
        moduleType == 'primary' ? 'Primary Sales' : 'Secondary Sales';
    final subtitle = [if (role.isNotEmpty) role, moduleLabel].join(' · ');

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => SettingsTab(onBack: () => Navigator.of(ctx).pop()),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 22,
          16,
          22,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryStrong],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Text(
                _initialsOf(name),
                style: const TextStyle(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.selected = false,
    this.iconColor,
    this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? (selected ? AppColors.primary : AppColors.textSecondary);
    final textStyleColor = textColor ?? (selected ? AppColors.primary : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textStyleColor,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
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

String _initialsOf(String name) {
  return initialsFromName(name);
}
