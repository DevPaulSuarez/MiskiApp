import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/common_widgets.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final versions = ref.watch(versionsProvider);
    final ingredients = ref.watch(ingredientsProvider);
    final categories = ref.watch(categoriesProvider);

    bool matchesIngredient(String recipeId) => versions.where((v) => v.recipeId == recipeId).any(
          (v) => v.ingredients.any((li) =>
              ingredients.where((i) => i.id == li.ingredientId).any((i) => i.name.toLowerCase().contains(q))),
        );

    final results = ref.watch(activeRecipesProvider).where((r) {
      if (_category != null && r.categoryId != _category) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) || r.description.toLowerCase().contains(q) || matchesIngredient(r.id);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Ceviche, limón, postres…',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${c.emoji} ${c.name}'),
                      selected: _category == c.id,
                      onSelected: (s) => setState(() => _category = s ? c.id : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    message: 'Prueba con otro nombre, ingrediente o categoría.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => RecipeListTile(recipe: results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
