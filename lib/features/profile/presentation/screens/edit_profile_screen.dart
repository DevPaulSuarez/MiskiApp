import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _me = ref.read(userByIdProvider(ref.read(currentUserIdProvider)));
  late final _name = TextEditingController(text: _me.name);
  late final _handle = TextEditingController(text: _me.handle.replaceFirst('@', ''));
  late final _bio = TextEditingController(text: _me.bio);
  late DateTime? _birthday = _me.birthday;
  late final Set<String> _categories = {..._me.favoriteCategoryIds};
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _handle, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Tu cumpleaños',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    try {
      await ref
          .read(usersProvider.notifier)
          .updateMe(
            ProfileUpdate(
              name: _name.text.trim(),
              handle: _handle.text.trim(),
              bio: _bio.text.trim(),
              birthday: _birthday,
              clearBirthday: _birthday == null,
              favoriteCategoryIds: _categories.toList(),
            ),
          );
      if (!mounted) return;
      showSuccess(context, 'Perfil actualizado');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _form.currentState!.validate();
      if (e.fieldErrors.isEmpty) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe tu nombre' : _error?.errorFor('name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _handle,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Usuario', prefixText: '@'),
              validator: (v) {
                final t = (v ?? '').trim().toLowerCase();
                if (t.length < 3) return 'Mínimo 3 caracteres';
                if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(t)) return 'Solo letras, números, punto y guion bajo';
                return _error?.errorFor('handle');
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLength: 160,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Sobre ti'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.cake_outlined),
              title: Text(_birthday == null ? 'Cumpleaños' : Fmt.date(_birthday!)),
              subtitle: const Text('Visible para que tus amigos te sorprendan'),
              trailing: _birthday == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _birthday = null),
                    ),
              onTap: _pickBirthday,
            ),
            const SizedBox(height: 20),
            Text('Categorías favoritas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  FilterChip(
                    label: Text('${c.emoji} ${c.name}'),
                    selected: _categories.contains(c.id),
                    onSelected: (on) => setState(() => on ? _categories.add(c.id) : _categories.remove(c.id)),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton(onPressed: _save, child: const Text('Guardar')),
        ),
      ),
    );
  }
}
