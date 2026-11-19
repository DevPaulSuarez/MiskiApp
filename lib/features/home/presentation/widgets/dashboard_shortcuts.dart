import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../../social/domain/social_entities.dart';
import '../../../social/presentation/providers/social_providers.dart';

/// Grid of tappable shortcut cards shown on the home dashboard.
class DashboardShortcuts extends ConsumerWidget {
  const DashboardShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meId = ref.watch(currentUserIdProvider);
    final ownCount = ref.watch(activeRecipesProvider).where((r) => r.authorId == meId).length;
    final favoriteCount = ref.watch(favoritesProvider).length;
    final pendingInvites = ref
        .watch(invitationsProvider)
        .where((i) => i.toUserId == meId && i.status == InvitationStatus.pending)
        .length;

    final cards = [
      _ShortcutCard(
        icon: Icons.menu_book_rounded,
        title: 'Mi recetario',
        subtitle: '$ownCount receta${ownCount == 1 ? '' : 's'} propia${ownCount == 1 ? '' : 's'}',
        onTap: () => context.push('/my-recipes'),
      ),
      _ShortcutCard(
        icon: Icons.add_circle_rounded,
        title: 'Nueva receta',
        subtitle: 'Crea desde cero',
        highlighted: true,
        onTap: () => context.push('/recipe-new'),
      ),
      _ShortcutCard(
        icon: Icons.mail_rounded,
        title: 'Invitaciones',
        subtitle: pendingInvites == 0 ? 'Sin pendientes' : '$pendingInvites pendiente${pendingInvites == 1 ? '' : 's'}',
        badge: pendingInvites,
        onTap: () => context.go('/invitations'),
      ),
      _ShortcutCard(
        icon: Icons.favorite_rounded,
        title: 'Favoritos',
        subtitle: '$favoriteCount guardada${favoriteCount == 1 ? '' : 's'}',
        onTap: () => context.go('/favorites'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: cards,
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  /// The one card painted with the accent color (the main action).
  final bool highlighted;

  bool get _isLight => !highlighted;
  Color get background => highlighted ? AppColors.accent : AppColors.surface;
  Color get foreground => highlighted ? AppColors.onAccent : AppColors.textPrimary;
  Color get accent => highlighted ? AppColors.onAccent : AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusM);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isLight ? AppColors.surfaceHigh : AppColors.onAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const Spacer(),
                  if (badge > 0)
                    Badge(label: Text('$badge'), backgroundColor: AppColors.danger)
                  else
                    Icon(Icons.arrow_forward_rounded, size: 18, color: foreground.withValues(alpha: 0.6)),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _isLight ? AppColors.textMuted : foreground.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
