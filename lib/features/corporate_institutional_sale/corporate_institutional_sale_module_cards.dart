import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/app/navigation/app_shell.dart';

class CorporateInstitutionalSaleModuleCards extends StatelessWidget {
  const CorporateInstitutionalSaleModuleCards({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canCorporate = auth.canAccessCorporateSales;
    final canInstitution = auth.canAccessInstitutionSales;
    if (!canCorporate && !canInstitution) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        if (canCorporate) ...[
          _ChannelModuleCard(
            title: 'Corporate Sales (CS)',
            description: 'Orders whose business type is Corporate Sales.',
            icon: Icons.apartment_outlined,
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppShell(
                  moduleType: 'primary',
                  businessType: 'cs',
                  moduleTitle: 'Corporate Sales (CS)',
                ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        if (canInstitution) ...[
          _ChannelModuleCard(
            title: 'Institution Sales (IS)',
            description: 'Orders whose business type is Institution Sales.',
            icon: Icons.account_balance_outlined,
            color: const Color(0xFF0F766E),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppShell(
                  moduleType: 'primary',
                  businessType: 'is',
                  moduleTitle: 'Institution Sales (IS)',
                ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ChannelModuleCard extends StatelessWidget {
  const _ChannelModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
