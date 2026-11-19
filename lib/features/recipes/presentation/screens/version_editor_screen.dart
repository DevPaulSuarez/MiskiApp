import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/ingredient_line_sheet.dart';

const _presetPhotos = [
  'https://images.unsplash.com/photo-1535399831218-d5bd36d1a6b3?w=900&q=80&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&q=80&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1547592180-85f173990554?w=900&q=80&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=900&q=80&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=900&q=80&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=900&q=80&auto=format&fit=crop',
];

/// Creates a new recipe (with V1) or a new version derived from [parentVersionId].
/// Published versions are never edited in place.
class VersionEditorScreen extends ConsumerStatefulWidget {
  const VersionEditorScreen({super.key, this.parentVersionId, this.initialName});
  final String? parentVersionId;

  /// Pre-fills the recipe name (e.g. coming from a search with no results).
  final String? initialName;

  @override
  ConsumerState<VersionEditorScreen> createState() => _VersionEditorScreenState();
}

class _VersionEditorScreenState extends ConsumerState<VersionEditorScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  final _form = GlobalKey<FormState>();

  // Recipe-level fields (only for new recipes)
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _categoryId = 'c3';
  String _photo = _presetPhotos.first;

  // Version fields
  final _title = TextEditingController();
  final _notes = TextEditingController();
  int _servings = 2;
  int _prep = 15;
  int _cook = 0;
  Difficulty _difficulty = Difficulty.easy;
  List<VersionIngredient> _ingredients = [];
  List<String> _steps = [];

  RecipeVersion? _parent;

  bool get _isNewRecipe => widget.parentVersionId == null;

  @override
  void initState() {
    super.initState();
    if (_isNewRecipe && widget.initialName != null) _name.text = widget.initialName!;
    if (!_isNewRecipe) {
      final p = ref.read(versionByIdProvider(widget.parentVersionId!))!;
      _parent = p;
      _servings = p.servings;
      _prep = p.prepMinutes;
      _cook = p.cookMinutes;
      _difficulty = p.difficulty;
      _ingredients = [...p.ingredients];
      _steps = [...p.steps];
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _title, _notes]) {
      c.dispose();
    }
    _tabs.dispose();
    super.dispose();
  }

  void _save() {
    // Tabs that are off-screen are not mounted, so check required fields directly.
    if (_isNewRecipe && _name.text.trim().length < 3) {
      _tabs.animateTo(0);
      _form.currentState?.validate();
      _error('Escribe el nombre de la receta (mínimo 3 caracteres).');
      return;
    }
    if (_ingredients.isEmpty) {
      _tabs.animateTo(1);
      _error('Agrega al menos un ingrediente.');
      return;
    }
    if (_steps.isEmpty) {
      _tabs.animateTo(2);
      _error('Agrega al menos un paso de preparación.');
      return;
    }

    final me = ref.read(currentUserIdProvider);
    final versions = ref.read(versionsProvider.notifier);
    final recipeId = _isNewRecipe ? newId('r') : _parent!.recipeId;
    final number = _isNewRecipe ? 1 : versions.nextNumber(recipeId);
    final version = RecipeVersion(
      id: newId('v'),
      recipeId: recipeId,
      number: number,
      title: _title.text.trim().isEmpty ? (_isNewRecipe ? 'Versión original' : 'Versión $number') : _title.text.trim(),
      parentVersionId: _parent?.id,
      createdBy: me,
      createdAt: DateTime.now(),
      servings: _servings,
      prepMinutes: _prep,
      cookMinutes: _cook,
      difficulty: _difficulty,
      ingredients: _ingredients,
      steps: _steps,
      notes: _notes.text.trim(),
    );

    if (_isNewRecipe) {
      ref.read(recipesProvider.notifier).save(Recipe(
            id: recipeId,
            name: _name.text.trim(),
            description: _description.text.trim(),
            imageUrl: _photo,
            categoryId: _categoryId,
            authorId: me,
            createdAt: DateTime.now(),
            mainVersionId: version.id,
          ));
    }
    versions.add(version);
    final notifications = ref.read(notificationsProvider.notifier);
    final recipe = _isNewRecipe ? null : ref.read(recipeByIdProvider(recipeId));
    final isContribution = recipe != null && recipe.authorId != me;
    if (isContribution) {
      // Modifying someone else's recipe: the version stays in their recipe
      // (counts as a contribution for me) and the author is told what changed.
      final changes = ref.read(versionComparatorProvider).ingredientChanges(
            _parent!,
            version,
            (id) => ref.read(ingredientByIdProvider(id))?.name ?? id,
          );
      final myName = ref.read(userByIdProvider(me)).name.split(' ').first;
      notifications.push(
        '$myName modificó tu receta',
        '${recipe.name} · V$number — ${changes.describe()}',
        route: '/version/${version.id}',
        toUserId: recipe.authorId,
      );
      final authorName = ref.read(userByIdProvider(recipe.authorId)).name.split(' ').first;
      notifications.push(
        'Aporte publicado',
        'Tu V$number de "${recipe.name}" se sumó a la receta de $authorName.',
        route: '/version/${version.id}',
      );
    } else {
      notifications.push(
        _isNewRecipe ? 'Receta creada' : 'Nueva versión publicada',
        _isNewRecipe ? '"${_name.text.trim()}" ya está en tu recetario.' : 'Publicaste la V$number.',
        route: '/version/${version.id}',
      );
    }
    showSuccess(context, _isNewRecipe ? 'Receta creada' : 'Versión V$number creada');
    context.pushReplacement('/version/${version.id}');
  }

  void _error(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.wine, content: Text(msg)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewRecipe ? 'Nueva receta' : 'Nueva versión desde V${_parent!.number}'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Datos'),
            Tab(text: 'Ingredientes (${_ingredients.length})'),
            Tab(text: 'Pasos (${_steps.length})'),
          ],
        ),
      ),
      body: Form(
        key: _form,
        child: TabBarView(
          controller: _tabs,
          children: [_buildInfoTab(), _buildIngredientsTab(), _buildStepsTab()],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_isNewRecipe ? 'Crear receta' : 'Publicar nueva versión'),
          ),
        ),
      ),
    );
  }

  /// Extra hint when editing a recipe that belongs to someone else.
  String _contributionNote() {
    final recipe = ref.read(recipeByIdProvider(_parent!.recipeId));
    if (recipe == null || recipe.authorId == ref.read(currentUserIdProvider)) return '';
    final author = ref.read(userByIdProvider(recipe.authorId)).name.split(' ').first;
    return '\nSe sumará como tu aporte a la receta de $author, y le avisaremos qué ingredientes agregaste o quitaste.';
  }

  Widget _buildInfoTab() {
    final categories = ref.watch(categoriesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_isNewRecipe)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Partes de una copia de V${_parent!.number}. La versión original no se modificará.'
              '${_contributionNote()}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        if (_isNewRecipe) ...[
          Text('Fotografía', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presetPhotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _photo == _presetPhotos[i];
                return GestureDetector(
                  onTap: () => setState(() => _photo = _presetPhotos[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 84,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? AppColors.wine : Colors.transparent, width: 3),
                    ),
                    child: RecipeImage(url: _presetPhotos[i], radius: 10),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre de la receta'),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Mínimo 3 caracteres' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _title,
          decoration: InputDecoration(
            labelText: 'Nombre de la versión',
            hintText: _isNewRecipe ? 'Versión original' : 'Ej. Más limón, menos cebolla',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '¿Qué cambia en esta versión? (opcional)'),
        ),
        const SizedBox(height: 16),
        _Stepper(label: 'Porciones', value: _servings, min: 1, onChanged: (v) => setState(() => _servings = v)),
        _Stepper(label: 'Preparación (min)', value: _prep, min: 0, step: 5, onChanged: (v) => setState(() => _prep = v)),
        _Stepper(label: 'Cocción (min)', value: _cook, min: 0, step: 5, onChanged: (v) => setState(() => _cook = v)),
        const SizedBox(height: 8),
        Text('Dificultad', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<Difficulty>(
          segments: [for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label))],
          selected: {_difficulty},
          onSelectionChanged: (s) => setState(() => _difficulty = s.first),
        ),
      ],
    );
  }

  Widget _buildIngredientsTab() {
    if (_ingredients.isEmpty) {
      return EmptyState(
        icon: Icons.egg_alt_outlined,
        title: 'Sin ingredientes',
        message: 'Agrega los ingredientes con su cantidad y unidad.',
        action: FilledButton.icon(onPressed: _addIngredient, icon: const Icon(Icons.add_rounded), label: const Text('Agregar ingrediente')),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (var i = 0; i < _ingredients.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: ValueKey('${_ingredients[i].ingredientId}-$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: AppColors.wine, borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              onDismissed: (_) => setState(() => _ingredients = [..._ingredients]..removeAt(i)),
              child: Card(
                child: ListTile(
                  onTap: () => _editIngredient(i),
                  title: Text(
                    ref.watch(ingredientByIdProvider(_ingredients[i].ingredientId))?.name ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text([
                    if (_ingredients[i].note.isNotEmpty) _ingredients[i].note,
                    if (_ingredients[i].purchase != null) 'Compra: ${Fmt.money(_ingredients[i].purchase!.price)}',
                  ].join(' · ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${Fmt.qty(_ingredients[i].quantity)} ${_ingredients[i].unit.symbol}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.wine),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text('Desliza a la izquierda para eliminar. Toca para editar.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _addIngredient, icon: const Icon(Icons.add_rounded), label: const Text('Agregar ingrediente')),
      ],
    );
  }

  Future<void> _addIngredient() async {
    final line = await showIngredientLineSheet(context);
    if (line == null) return;
    if (_ingredients.any((l) => l.ingredientId == line.ingredientId)) {
      _error('Ese ingrediente ya está en la receta. Edita su cantidad.');
      return;
    }
    setState(() => _ingredients = [..._ingredients, line]);
  }

  Future<void> _editIngredient(int i) async {
    final line = await showIngredientLineSheet(context, initial: _ingredients[i]);
    if (line != null) setState(() => _ingredients = [..._ingredients]..[i] = line);
  }

  Widget _buildStepsTab() {
    return Column(children: [
      Expanded(
        child: _steps.isEmpty
            ? const EmptyState(icon: Icons.format_list_numbered_rounded, title: 'Sin pasos', message: 'Describe la preparación paso a paso.')
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _steps.length,
                onReorderItem: (from, to) => setState(() {
                  final s = _steps.removeAt(from);
                  _steps.insert(to, s);
                }),
                itemBuilder: (_, i) => Padding(
                  key: ValueKey('step-$i-${_steps[i].hashCode}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 12, right: 4),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.wine,
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      title: Text(_steps[i], style: const TextStyle(fontSize: 14)),
                      onTap: () => _editStep(i),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.wine),
                          onPressed: () => setState(() => _steps.removeAt(i)),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(children: [
          Text('Arrastra ⠿ para reordenar. Toca un paso para editarlo.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editStep(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar paso'),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _editStep(int? i) async {
    final controller = TextEditingController(text: i == null ? '' : _steps[i]);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(i == null ? 'Nuevo paso' : 'Paso ${i + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Describe el paso…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => i == null ? _steps = [..._steps, result] : _steps[i] = result);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged, this.min = 0, this.step = 1});
  final String label;
  final int value;
  final int min;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.wine),
          ),
        ]),
      );
}
