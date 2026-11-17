import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/measure_unit.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_providers.dart';

/// Bottom sheet to add or edit one ingredient line of a draft version.
Future<VersionIngredient?> showIngredientLineSheet(BuildContext context, {VersionIngredient? initial}) =>
    showModalBottomSheet<VersionIngredient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (_) => _IngredientLineSheet(initial: initial),
    );

class _IngredientLineSheet extends ConsumerStatefulWidget {
  const _IngredientLineSheet({this.initial});
  final VersionIngredient? initial;

  @override
  ConsumerState<_IngredientLineSheet> createState() => _IngredientLineSheetState();
}

class _IngredientLineSheetState extends ConsumerState<_IngredientLineSheet> {
  final _form = GlobalKey<FormState>();
  late final _qty = TextEditingController(text: widget.initial == null ? '' : Fmt.qty(widget.initial!.quantity));
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late final _price = TextEditingController(text: widget.initial?.purchase?.price.toStringAsFixed(2) ?? '');
  late final _buyQty = TextEditingController(text: widget.initial?.purchase == null ? '' : Fmt.qty(widget.initial!.purchase!.quantity));
  String _name = '';
  late MeasureUnit _unit = widget.initial?.unit ?? MeasureUnit.gram;
  late MeasureUnit _buyUnit = widget.initial?.purchase?.unit ?? _unit;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    for (final c in [_qty, _note, _price, _buyQty]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changeUnit(MeasureUnit next) {
    final q = double.tryParse(_qty.text.replaceAll(',', '.'));
    setState(() {
      if (q != null && _unit.isCompatibleWith(next)) _qty.text = Fmt.qty(_unit.convert(q, next));
      if (!_buyUnit.isCompatibleWith(next)) _buyUnit = next;
      _unit = next;
    });
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final ingredientId = _editing
        ? widget.initial!.ingredientId
        : ref.read(ingredientsProvider.notifier).findOrCreate(
              _name,
              () => Ingredient(id: newId('i'), name: _name.trim(), category: 'Otros', defaultUnit: _unit),
            ).id;
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    final buyQty = double.tryParse(_buyQty.text.replaceAll(',', '.'));
    Navigator.pop(
      context,
      VersionIngredient(
        ingredientId: ingredientId,
        quantity: double.parse(_qty.text.replaceAll(',', '.')),
        unit: _unit,
        note: _note.text.trim(),
        purchase: price != null && buyQty != null && buyQty > 0
            ? PurchaseInfo(price: price, quantity: buyQty, unit: _buyUnit)
            : null,
      ),
    );
  }

  String? _positive(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    return d == null || d <= 0 ? 'Ingresa un número mayor a 0' : null;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(ingredientsProvider);
    final editingName = _editing ? ref.watch(ingredientByIdProvider(widget.initial!.ingredientId))?.name : null;
    final units = _editing ? widget.initial!.unit.compatibleUnits.toList() : MeasureUnit.values;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_editing ? 'Editar $editingName' : 'Agregar ingrediente', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (!_editing)
                Autocomplete<Ingredient>(
                  displayStringForOption: (i) => i.name,
                  optionsBuilder: (v) => v.text.isEmpty
                      ? const Iterable.empty()
                      : catalog.where((i) => i.name.toLowerCase().contains(v.text.toLowerCase())),
                  onSelected: (i) {
                    _name = i.name;
                    _changeUnit(i.defaultUnit);
                  },
                  fieldViewBuilder: (_, controller, focus, _) => TextFormField(
                    controller: controller,
                    focusNode: focus,
                    onChanged: (v) => _name = v,
                    decoration: const InputDecoration(
                      labelText: 'Ingrediente',
                      helperText: 'Elige del catálogo o escribe uno nuevo',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    validator: _positive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<MeasureUnit>(
                    key: ValueKey('unit-$_unit'),
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u.label))],
                    onChanged: (u) => u == null ? null : _changeUnit(u),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
              ),
              const SizedBox(height: 18),
              Text('Precio de compra (opcional)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio \$'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _buyQty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cant.'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<MeasureUnit>(
                    key: ValueKey('buy-$_buyUnit'),
                    initialValue: _buyUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: [for (final u in _unit.compatibleUnits) DropdownMenuItem(value: u, child: Text(u.symbol))],
                    onChanged: (u) => setState(() => _buyUnit = u ?? _buyUnit),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: Text(_editing ? 'Guardar cambios' : 'Agregar')),
            ],
          ),
        ),
      ),
    );
  }
}
