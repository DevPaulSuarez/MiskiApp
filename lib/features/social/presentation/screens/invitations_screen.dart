import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../domain/social_entities.dart';
import '../providers/social_providers.dart';
import '../widgets/notifications_action.dart';

Color invitationColor(InvitationStatus s) => switch (s) {
  InvitationStatus.pending => AppColors.gold,
  InvitationStatus.accepted => AppColors.success,
  InvitationStatus.rejected => AppColors.danger,
  InvitationStatus.completed => AppColors.textMuted,
};

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    final all = ref.watch(invitationsProvider);
    final received = all.where((i) => i.toUserId == me).toList();
    final sent = all.where((i) => i.fromUserId == me).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invitaciones'),
          actions: const [NotificationsAction()],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Recibidas (${received.length})'),
              Tab(text: 'Enviadas (${sent.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InvitationList(items: received, received: true),
            _InvitationList(items: sent, received: false),
          ],
        ),
      ),
    );
  }
}

class _InvitationList extends StatelessWidget {
  const _InvitationList({required this.items, required this.received});
  final List<Invitation> items;
  final bool received;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.mail_outline_rounded,
        title: received ? 'No tienes invitaciones' : 'No has enviado invitaciones',
        message: received
            ? 'Cuando alguien te invite a probar un plato aparecerá aquí.'
            : 'Abre una receta y toca "Invitar" para que otros prueben tu versión.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _InvitationCard(invitation: items[i], received: received),
    );
  }
}

class _InvitationCard extends ConsumerWidget {
  const _InvitationCard({required this.invitation, required this.received});
  final Invitation invitation;
  final bool received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = invitation;
    final other = ref.watch(userByIdProvider(received ? inv.fromUserId : inv.toUserId));
    final recipe = ref.watch(recipeByIdProvider(inv.recipeId));
    final version = ref.watch(versionByIdProvider(inv.versionId));
    final notifier = ref.read(invitationsProvider.notifier);
    final alreadyRated = ref.watch(ratingsProvider).any((r) => r.invitationId == inv.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/version/${inv.versionId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: RecipeImage(url: recipe?.imageUrl ?? '', radius: AppTheme.radiusS),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('V${version?.number} · ${version?.title}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          '${received ? 'De' : 'Para'} ${other.name} · ${Fmt.relative(inv.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(inv.status.label, color: invitationColor(inv.status)),
                ],
              ),
              if (inv.message.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
                  child: Text('“${inv.message}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                ),
              ],
              if (received && inv.status == InvitationStatus.pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          notifier.setStatus(inv.id, InvitationStatus.rejected);
                          showSuccess(context, 'Invitación rechazada');
                        },
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          notifier.setStatus(inv.id, InvitationStatus.accepted);
                          showSuccess(context, '¡Aceptada! Cuando lo pruebes podrás calificarlo.');
                        },
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
              if (received && inv.status == InvitationStatus.accepted && !alreadyRated) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/version/${inv.versionId}/rate?inv=${inv.id}'),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Ya lo probé · Calificar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
