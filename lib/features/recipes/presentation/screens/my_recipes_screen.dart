import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';

import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_showcase.dart';

/// The current user's own dishes, with a search box and the "new recipe" button.
class MyRecipesScreen extends ConsumerStatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  ConsumerState<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends ConsumerState<MyRecipesScreen> {
  String _query = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final status = _showArchived ? RecipeStatus.archived : RecipeStatus.active;
    final versions = ref.watch(versionsProvider);
    final ingredients = {for (final i in ref.watch(ingredientsProvider)) i.id: i.name.toLowerCase()};
    final q = _query.trim().toLowerCase();

    bool matches(Recipe r) {
      if (q.isEmpty) return true;
      if (r.name.toLowerCase().contains(q) || r.description.toLowerCase().contains(q)) return true;
      return versions
          .where((v) => v.recipeId == r.id)
          .any((v) => v.ingredients.any((li) => (ingredients[li.ingredientId] ?? '').contains(q)));
    }

    final mine = ref.watch(recipesProvider).where((r) => r.authorId == me && r.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shown = mine.where(matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis recetas'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Ver activas' : 'Ver archivadas',
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar en mis recetas…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_showArchived)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge('Mostrando archivadas', color: AppColors.textMuted),
              ),
            ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: q.isEmpty ? Icons.menu_book_rounded : Icons.search_off_rounded,
                    title: q.isEmpty
                        ? (_showArchived ? 'No tienes recetas archivadas' : 'Aún no tienes recetas propias')
                        : 'Sin resultados',
                    message: q.isEmpty
                        ? 'Toca + para crear tu primera receta.'
                        : 'Prueba con otro nombre o ingrediente.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => RecipeRow(recipe: shown[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recipe-new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva receta', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
