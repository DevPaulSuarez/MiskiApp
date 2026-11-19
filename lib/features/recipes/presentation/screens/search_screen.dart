import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/common_widgets.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Pre-filled search, e.g. a friend's favorite food.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery ?? '');
  late String _query = widget.initialQuery ?? '';
  String? _category;

  /// Short connector words ignored when looking for similar recipes.
  static const _stopwords = {'de', 'del', 'la', 'el', 'los', 'las', 'con', 'y', 'en', 'al', 'a'};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final versions = ref.watch(versionsProvider);
    final ingredients = ref.watch(ingredientsProvider);
    final categories = ref.watch(categoriesProvider);

    bool matchesIngredient(String recipeId, String term) => versions
        .where((v) => v.recipeId == recipeId)
        .any(
          (v) => v.ingredients.any(
            (li) => ingredients.where((i) => i.id == li.ingredientId).any((i) => i.name.toLowerCase().contains(term)),
          ),
        );
    bool matches(String recipeId, String name, String description, String term) =>
        name.toLowerCase().contains(term) ||
        description.toLowerCase().contains(term) ||
        matchesIngredient(recipeId, term);

    final pool = ref.watch(activeRecipesProvider).where((r) => _category == null || r.categoryId == _category).toList();
    final results = q.isEmpty ? pool : pool.where((r) => matches(r.id, r.name, r.description, q)).toList();

    // No exact match for a multi-word query ("Torta de chocolate"): fall back to any meaningful word.
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2 && !_stopwords.contains(w)).toList();
    final similar = results.isEmpty && words.length > 1
        ? pool.where((r) => words.any((w) => matches(r.id, r.name, r.description, w))).toList()
        : const [];
    final shown = results.isNotEmpty ? results : similar;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialQuery == null,
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
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    message: q.isEmpty
                        ? 'Prueba con otro nombre, ingrediente o categoría.'
                        : 'Nadie ha subido "${_query.trim()}" todavía. ¡Puedes ser el primero!',
                    action: q.isEmpty ? null : _createButton(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'No encontramos "${_query.trim()}" exacto. Recetas parecidas:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      for (final r in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RecipeListTile(recipe: r),
                        ),
                      if (results.isEmpty) Center(child: _createButton()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _createButton() => FilledButton.icon(
    onPressed: () => context.push(Uri(path: '/recipe-new', queryParameters: {'name': _query.trim()}).toString()),
    icon: const Icon(Icons.add_rounded),
    label: Text('Crear "${_query.trim()}"'),
  );
}
