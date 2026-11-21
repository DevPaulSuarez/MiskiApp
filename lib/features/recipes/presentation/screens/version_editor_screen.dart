import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../data/recipe_data_providers.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/dish_matcher.dart';
import '../providers/preparation_providers.dart';
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
  late String _categoryId = _defaultCategory();
  String _photo = _presetPhotos.first;

  /// A photo taken or picked on this phone; uploaded when the recipe is published.
  String? _localPhoto;

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

  String _defaultCategory() {
    final cats = ref.read(categoriesProvider);
    return (cats.where((c) => c.name == 'Platos principales').firstOrNull ?? cats.firstOrNull)?.id ?? '';
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file != null) setState(() => _localPhoto = file.path);
    } catch (_) {
      if (mounted) _error('No pudimos abrir la cámara o la galería. Revisa los permisos de Miski.');
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

  Future<void> _save() async {
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

    if (!_isNewRecipe) {
      await _publish(target: ref.read(recipeByIdProvider(_parent!.recipeId)), parent: _parent);
      return;
    }

    // A "new" recipe that shares most ingredients with an existing dish is
    // probably the same dish: offer to save it as the user's version of it.
    final match = ref
        .read(dishMatcherProvider)
        .byIngredients(_ingredients.map((i) => i.ingredientId), ref.read(recipesProvider), ref.read(versionsProvider));
    if (match != null) {
      final asVersion = await _askSameDish(match);
      if (!mounted || asVersion == null) return;
      if (asVersion) {
        await _publish(target: match.recipe, parent: match.version);
        return;
      }
    }
    await _publish();
  }

  Future<bool?> _askSameDish(DishMatch match) {
    final author = ref.read(userByIdProvider(match.version.createdBy));
    final me = ref.read(currentUserIdProvider);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Es el mismo plato?'),
        content: Text(
          'Tus ingredientes coinciden en un ${match.percent}% con "${match.recipe.name}" '
          '(V${match.version.number} de ${author.id == me ? 'ti' : author.firstName}).\n\n'
          'Para no repetir platos en la búsqueda, puedes guardarla como tu versión de ese plato, con tu nombre.\n\n'
          'Si es otro plato con ingredientes parecidos (otra técnica u otra preparación), créalo como plato nuevo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Crear plato nuevo')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar como mi versión')),
        ],
      ),
    );
  }

  /// Saves a new dish (when [target] is null) or a new version of [target] built from [parent].
  Future<void> _publish({Recipe? target, RecipeVersion? parent}) async {
    final isNewDish = target == null;
    final typedTitle = _title.text.trim();
    final draft = VersionDraft(
      // Merged from the "new recipe" form: the name they typed describes their version.
      title: typedTitle.isNotEmpty ? typedTitle : (!isNewDish && _isNewRecipe ? _name.text.trim() : ''),
      servings: _servings,
      prepMinutes: _prep,
      cookMinutes: _cook,
      difficulty: _difficulty,
      ingredients: _ingredients,
      steps: _steps,
      notes: _notes.text.trim(),
    );

    final version = await runAction(context, () async {
      if (!isNewDish) return ref.read(versionsProvider.notifier).add(target.id, parent!.id, draft);
      final photo = _localPhoto == null ? _photo : await ref.read(recipeRepositoryProvider).uploadImage(_localPhoto!);
      return ref
          .read(recipesProvider.notifier)
          .createDish(
            DishDraft(
              name: _name.text.trim(),
              description: _description.text.trim(),
              imageUrl: photo,
              categoryId: _categoryId,
            ),
            draft,
          );
    });
    if (version == null || !mounted) return;

    final me = ref.read(currentUserIdProvider);
    final String message;
    if (isNewDish) {
      message = 'Receta creada';
    } else if (target.authorId != me) {
      // My way of preparing someone else's dish: it stays in their dish under my
      // name, and the author is told which ingredients I added or removed.
      message = 'Tu versión V${version.number} ya aparece con tu nombre en el plato';
    } else {
      message = 'Versión V${version.number} creada';
    }
    showSuccess(context, message);
    context.pushReplacement('/version/${version.id}');
  }

  void _error(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(msg)));

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
        child: TabBarView(controller: _tabs, children: [_buildInfoTab(), _buildIngredientsTab(), _buildStepsTab()]),
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
    return '\nTu versión quedará con tu nombre dentro del plato de $author, y le avisaremos qué ingredientes agregaste o quitaste.';
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
              itemCount: _presetPhotos.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                if (index == 0) return _OwnPhotoTile(path: _localPhoto, onTap: _pickPhoto);
                final i = index - 1;
                final selected = _localPhoto == null && _photo == _presetPhotos[i];
                return GestureDetector(
                  onTap: () => setState(() {
                    _photo = _presetPhotos[i];
                    _localPhoto = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 84,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 3),
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
          _SimilarDishesHint(name: _name),
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
                DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.emoji} ${c.name}', overflow: TextOverflow.ellipsis),
                ),
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
        _Stepper(
          label: 'Preparación (min)',
          value: _prep,
          min: 0,
          step: 5,
          onChanged: (v) => setState(() => _prep = v),
        ),
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
        action: FilledButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar ingrediente'),
        ),
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
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
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
                  subtitle: Text(
                    [
                      if (_ingredients[i].note.isNotEmpty) _ingredients[i].note,
                      if (_ingredients[i].purchase != null) 'Compra: ${Fmt.money(_ingredients[i].purchase!.price)}',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${Fmt.qty(_ingredients[i].quantity)} ${_ingredients[i].unit.symbol}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Desliza a la izquierda para eliminar. Toca para editar.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar ingrediente'),
        ),
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
    return Column(
      children: [
        Expanded(
          child: _steps.isEmpty
              ? const EmptyState(
                  icon: Icons.format_list_numbered_rounded,
                  title: 'Sin pasos',
                  message: 'Describe la preparación paso a paso.',
                )
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
                          backgroundColor: AppColors.surfaceHigh,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(_steps[i], style: const TextStyle(fontSize: 14)),
                        onTap: () => _editStep(i),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                              onPressed: () => setState(() => _steps.removeAt(i)),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              Text(
                'Arrastra ⠿ para reordenar. Toca un paso para editarlo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _editStep(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar paso'),
              ),
            ],
          ),
        ),
      ],
    );
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
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + step),
          icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
        ),
      ],
    ),
  );
}

/// While typing a new recipe's name, points to existing dishes with a similar name.
class _SimilarDishesHint extends ConsumerWidget {
  const _SimilarDishesHint({required this.name});
  final TextEditingController name;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ValueListenableBuilder(
    valueListenable: name,
    builder: (context, value, _) {
      final matches = ref.read(dishMatcherProvider).byName(value.text, ref.watch(activeRecipesProvider));
      if (matches.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final r in matches.take(2))
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ya existe "${r.name}" (${ref.watch(preparationsProvider(r.id)).length} '
                      'forma${ref.watch(preparationsProvider(r.id)).length == 1 ? '' : 's'} de prepararlo). '
                      '¿Es el mismo plato?',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushReplacement('/version/${r.mainVersionId}/derive'),
                    child: const Text('Crear mi versión'),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// First tile of the photo row: take or pick your own photo.
class _OwnPhotoTile extends StatelessWidget {
  const _OwnPhotoTile({required this.path, required this.onTap});
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 84,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: path != null ? AppColors.accent : Colors.transparent, width: 3),
      ),
      child: path != null
          ? RecipeImage(url: path!, radius: 10)
          : Container(
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: AppColors.accent),
                  const SizedBox(height: 4),
                  Text('Tu foto', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
    ),
  );
}
