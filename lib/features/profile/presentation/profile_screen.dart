import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../recipes/presentation/providers/recipe_providers.dart';
import '../../recipes/presentation/screens/cookbook_screen.dart';
import '../../recipes/presentation/widgets/recipe_card.dart';
import '../../social/domain/social_entities.dart';
import '../../social/presentation/providers/social_providers.dart';
import 'widgets/favorite_foods_sheet.dart';

/// Profile of [userId], or of the current user when null (the Perfil tab).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meId = ref.watch(currentUserIdProvider);
    final uid = userId ?? meId;
    final isMe = uid == meId;
    final user = ref.watch(userByIdProvider(uid));
    final recipes = ref.watch(recipesProvider);
    final recipeById = {for (final r in recipes) r.id: r};

    // Recipes the user owns.
    final ownRecipes = recipes.where((r) => r.authorId == uid).toList();
    // Versions published on someone else's recipe: they live in that recipe, but count as contributions.
    final contributions =
        ref.watch(versionsProvider).where((v) => v.createdBy == uid && recipeById[v.recipeId]?.authorId != uid).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Recipes tried and rated (one entry per recipe, keeping the latest rating).
    final ratings = ref.watch(ratingsProvider).where((r) => r.userId == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final triedByRecipe = <String, int>{};
    for (final r in ratings) {
      triedByRecipe.putIfAbsent(r.recipeId, () => r.stars);
    }

    final favCategories = ref.watch(categoriesProvider).where((c) => user.favoriteCategoryIds.contains(c.id)).toList();
    final daysToBirthday = user.daysUntilBirthday(DateTime.now());

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            user: user,
            showBack: Navigator.of(context).canPop(),
            stats: [
              _Stat('${ownRecipes.length}', 'Recetas\npropias'),
              _Stat('${contributions.length}', 'Aportes a\notras recetas'),
              _Stat('${triedByRecipe.length}', 'Probadas y\ncalificadas'),
            ],
          ),

          if (!isMe && daysToBirthday != null && daysToBirthday <= upcomingBirthdayDays)
            _BirthdaySurprise(user: user, days: daysToBirthday),

          SectionHeader(
            'Comidas favoritas',
            action: isMe ? 'Editar' : null,
            onAction: () => showFavoriteFoodsSheet(context, ref, user),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: user.favoriteFoods.isEmpty
                ? Text(
                    isMe
                        ? 'Cuéntales a tus amigos qué te encanta comer. Así podrán sorprenderte en tu cumpleaños.'
                        : '${user.firstName} aún no agregó sus comidas favoritas.',
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in user.favoriteFoods)
                        ActionChip(
                          avatar: const Icon(Icons.restaurant_rounded, size: 16, color: AppColors.wine),
                          label: Text(f, style: const TextStyle(fontWeight: FontWeight.w700)),
                          backgroundColor: AppColors.beigeSoft,
                          side: BorderSide.none,
                          tooltip: 'Buscar recetas de $f',
                          onPressed: () => context.push(Uri(path: '/search', queryParameters: {'q': f}).toString()),
                        ),
                    ],
                  ),
          ),

          const SectionHeader('Categorías favoritas'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: favCategories.isEmpty
                ? const Text('Sin categorías favoritas.')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in favCategories)
                        ActionChip(
                          label: Text('${c.emoji} ${c.name}'),
                          onPressed: () {
                            ref.read(cookbookCategoryProvider.notifier).select(c.id);
                            context.go('/recipes');
                          },
                        ),
                    ],
                  ),
          ),

          SectionHeader(isMe ? 'Mis recetas' : 'Sus recetas'),
          if (ownRecipes.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Aún no hay recetas propias.')),
          for (final r in ownRecipes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: RecipeListTile(recipe: r),
            ),

          SectionHeader(isMe ? 'Mis aportes' : 'Sus aportes'),
          if (contributions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isMe
                    ? 'Cuando modifiques la receta de otra persona, tu versión aparecerá aquí.'
                    : 'Aún no modificó recetas de otras personas.',
              ),
            ),
          for (final v in contributions)
            Builder(
              builder: (context) {
                final recipe = recipeById[v.recipeId]!;
                final author = ref.watch(userByIdProvider(recipe.authorId));
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.beigeSoft,
                    child: Icon(Icons.account_tree_rounded, color: AppColors.wine),
                  ),
                  title: Text('${recipe.name} · V${v.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Receta de ${author.firstName} · ${v.title}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/version/${v.id}'),
                );
              },
            ),

          const SectionHeader('Probadas y calificadas'),
          if (triedByRecipe.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Aún no calificó ninguna receta.'),
            ),
          for (final entry in triedByRecipe.entries)
            if (recipeById[entry.key] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: RecipeListTile(
                  recipe: recipeById[entry.key]!,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Nota', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(
                        '${entry.value} ★',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
              ),

          if (isMe) ...[
            const SectionHeader('Ajustes'),
            const _SettingTile(icon: Icons.lock_outline_rounded, label: 'Privacidad de recetas'),
            const _SettingTile(icon: Icons.notifications_outlined, label: 'Notificaciones'),
            const _SettingTile(icon: Icons.logout_rounded, label: 'Cerrar sesión'),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.showBack, required this.stats});
  final AppUser user;
  final bool showBack;
  final List<Widget> stats;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, top + 24, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusL)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: UserAvatar(initials: user.initials, radius: 40),
              ),
              const SizedBox(height: 12),
              Text(
                user.name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                user.handle,
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
              ),
              if (user.birthday != null) ...[
                const SizedBox(height: 8),
                InfoPill(icon: Icons.cake_rounded, label: 'Cumpleaños: ${Fmt.birthday(user.birthday!)}', dark: true),
              ],
              const SizedBox(height: 8),
              Text(
                user.bio,
                style: const TextStyle(color: AppColors.beige),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(children: stats),
            ],
          ),
        ),
        if (showBack)
          Positioned(
            top: top + 4,
            left: 4,
            child: const BackButton(color: Colors.white),
          ),
      ],
    );
  }
}

/// Shown on someone else's profile when their birthday is close.
class _BirthdaySurprise extends StatelessWidget {
  const _BirthdaySurprise({required this.user, required this.days});
  final AppUser user;
  final int days;

  @override
  Widget build(BuildContext context) {
    final when = switch (days) {
      0 => '¡Hoy es su cumpleaños!',
      1 => 'Cumple mañana',
      _ => 'Cumple en $days días',
    };
    final foods = user.favoriteFoods;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.wine, borderRadius: BorderRadius.circular(AppTheme.radiusM)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        when,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        foods.isEmpty
                            ? 'Aún no sabemos su comida favorita.'
                            : 'Dale una sorpresa con una de sus comidas favoritas. Toca una para buscar la receta 👇',
                        style: const TextStyle(color: AppColors.beige, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.beige, fontSize: 12),
        ),
      ],
    ),
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
