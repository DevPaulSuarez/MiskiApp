import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/widgets/notifications_action.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/recipe_card.dart';

class CookbookCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final cookbookCategoryProvider = NotifierProvider<CookbookCategoryNotifier, String?>(CookbookCategoryNotifier.new);

class CookbookScreen extends ConsumerStatefulWidget {
  const CookbookScreen({super.key});

  @override
  ConsumerState<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends ConsumerState<CookbookScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(cookbookCategoryProvider);
    final categories = ref.watch(categoriesProvider);
    final status = _showArchived ? RecipeStatus.archived : RecipeStatus.active;
    final recipes = ref
        .watch(recipesProvider)
        .where((r) => r.status == status && (selected == null || r.categoryId == selected))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetario'),
        actions: [
          IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded)),
          IconButton(
            tooltip: _showArchived ? 'Ver activas' : 'Ver archivadas',
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
          ),
          const NotificationsAction(),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todas'),
                    selected: selected == null,
                    onSelected: (_) => ref.read(cookbookCategoryProvider.notifier).select(null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${c.emoji} ${c.name}'),
                      selected: selected == c.id,
                      onSelected: (_) => ref.read(cookbookCategoryProvider.notifier).select(c.id),
                    ),
                  ),
              ],
            ),
          ),
          if (_showArchived)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(alignment: Alignment.centerLeft, child: StatusBadge('Mostrando archivadas', color: Colors.brown)),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: recipes.isEmpty
                  ? EmptyState(
                      key: const ValueKey('empty'),
                      icon: Icons.menu_book_rounded,
                      title: _showArchived ? 'No hay recetas archivadas' : 'Aún no hay recetas aquí',
                      message: 'Crea una receta nueva o prueba otra categoría.',
                      action: _showArchived
                          ? null
                          : FilledButton.icon(
                              onPressed: () => context.push('/recipe-new'),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Crear receta'),
                            ),
                    )
                  : GridView.builder(
                      key: ValueKey('$selected-$_showArchived'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 222,
                      ),
                      itemCount: recipes.length,
                      itemBuilder: (_, i) => RecipeCard(recipe: recipes[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recipe-new'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
