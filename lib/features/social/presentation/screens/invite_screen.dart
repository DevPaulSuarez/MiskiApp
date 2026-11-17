import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../providers/social_providers.dart';

/// Select users and send an invitation tied to one specific version.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.versionId});
  final String versionId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _selected = <String>{};
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _send() {
    final version = ref.read(versionByIdProvider(widget.versionId))!;
    ref.read(invitationsProvider.notifier).send(
          recipeId: version.recipeId,
          versionId: version.id,
          toUserIds: _selected.toList(),
          message: _message.text.trim(),
        );
    ref.read(notificationsProvider.notifier).push(
          'Invitaciones enviadas',
          'Invitaste a ${_selected.length} persona${_selected.length > 1 ? 's' : ''} a probar la V${version.number}.',
          route: '/invitations',
        );
    showSuccess(context, 'Invitaciones enviadas');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final users = ref.watch(usersProvider).where((u) => u.id != me).toList();
    final version = ref.watch(versionByIdProvider(widget.versionId))!;
    final recipe = ref.watch(recipeByIdProvider(version.recipeId))!;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitar a probar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: SizedBox(width: 48, height: 48, child: RecipeImage(url: recipe.imageUrl, radius: 10)),
              title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('V${version.number} · ${version.title}'),
            ),
          ),
          const SectionHeader('¿A quién invitas?'),
          for (final u in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: CheckboxListTile(
                  value: _selected.contains(u.id),
                  activeColor: AppColors.wine,
                  onChanged: (v) => setState(() => v! ? _selected.add(u.id) : _selected.remove(u.id)),
                  secondary: UserAvatar(initials: u.initials),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(u.handle),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Mensaje (opcional)', hintText: '¡Ven a probar mi ceviche el sábado!'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: Text(_selected.isEmpty ? 'Selecciona invitados' : 'Enviar a ${_selected.length}'),
          ),
        ),
      ),
    );
  }
}
