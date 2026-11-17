import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/common_widgets.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoritesProvider);
    final recipes = ref.watch(recipesProvider).where((r) => favIds.contains(r.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: recipes.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Aún no tienes favoritos',
              message: 'Toca el corazón en cualquier receta para guardarla aquí.',
              action: OutlinedButton(onPressed: () => context.go('/recipes'), child: const Text('Explorar recetario')),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: recipes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => RecipeListTile(recipe: recipes[i]),
            ),
    );
  }
}
