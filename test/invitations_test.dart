import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/core/network/api_exception.dart';
import 'package:miski_app/core/session/session_controller.dart';
import 'package:miski_app/features/social/presentation/providers/social_providers.dart';
import 'package:miski_app/features/social/presentation/screens/invite_screen.dart';

// Demo data, signed in as u1 (Paul). For v2 of the ceviche he already invited
// Diego (u5, pending) and Carlos (u2, accepted, not rated yet).
void main() {
  test('cannot invite again while the invitation is open', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(sessionProvider.future);
    final invitations = c.read(invitationsProvider.notifier);
    final before = c.read(invitationsProvider).length;

    await expectLater(
      invitations.send(versionId: 'v2', toUserIds: ['u4', 'u5'], message: ''),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Ya invitaste a Diego a esta versión.')),
    );
    expect(c.read(invitationsProvider).length, before); // nobody was invited

    // Lucía's invitation to v1 is completed (she rated), so she can be invited again.
    await invitations.send(versionId: 'v1', toUserIds: ['u4'], message: '');
    expect(c.read(openInviteesProvider('v1')).keys, contains('u4'));
  });

  testWidgets('invite screen locks people who already have an open invitation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: _SignedIn(child: InviteScreen(versionId: 'v2')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya invitado (pendiente)'), findsOneWidget); // Diego
    expect(find.textContaining('Ya invitado (aceptada)'), findsOneWidget); // Carlos

    final diego = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Diego Torres'));
    expect(diego.value, isTrue);
    expect(diego.onChanged, isNull);

    // Locked rows don't count as a new selection.
    expect(find.text('Selecciona invitados'), findsOneWidget);
    await tester.tap(find.text('María Quispe'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar a 1'), findsOneWidget);
  });
}

/// Waits for the demo session before showing [child].
class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(sessionProvider).hasValue ? child : const SizedBox();
}
