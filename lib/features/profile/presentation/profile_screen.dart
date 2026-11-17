import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../recipes/presentation/providers/recipe_providers.dart';
import '../../recipes/presentation/widgets/recipe_card.dart';
import '../../social/presentation/providers/social_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meId = ref.watch(currentUserIdProvider);
    final me = ref.watch(userByIdProvider(meId));
    final myRecipes = ref.watch(recipesProvider).where((r) => r.authorId == meId).toList();
    final myVersions = ref.watch(versionsProvider).where((v) => v.createdBy == meId).length;
    final myRatings = ref.watch(ratingsProvider).where((r) => r.userId == meId).length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusL)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: UserAvatar(initials: me.initials, radius: 40),
              ),
              const SizedBox(height: 12),
              Text(me.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(me.handle, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(me.bio, style: const TextStyle(color: AppColors.beige), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Row(children: [
                _Stat('${myRecipes.length}', 'Recetas'),
                _Stat('$myVersions', 'Versiones'),
                _Stat('$myRatings', 'Valoraciones'),
              ]),
            ]),
          ),
          const SectionHeader('Mis recetas'),
          if (myRecipes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Aún no has creado recetas.'),
            ),
          for (final r in myRecipes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: RecipeListTile(recipe: r),
            ),
          const SectionHeader('Ajustes'),
          const _SettingTile(icon: Icons.lock_outline_rounded, label: 'Privacidad de recetas'),
          const _SettingTile(icon: Icons.notifications_outlined, label: 'Notificaciones'),
          const _SettingTile(icon: Icons.logout_rounded, label: 'Cerrar sesión'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.beige, fontSize: 12)),
        ]),
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.forest),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showSuccess(context, 'Disponible cuando conectemos el backend'),
      );
}
