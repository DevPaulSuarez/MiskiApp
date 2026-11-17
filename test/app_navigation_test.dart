import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/app/app.dart';

void main() {
  testWidgets('splash -> home -> recipe detail -> adjust servings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    expect(find.text('Miski'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué cocinamos hoy?'), findsOneWidget);

    await tester.tap(find.text('Ceviche peruano de tilapia').first);
    await tester.pumpAndSettle();
    expect(find.text('Más limón, menos cebolla'), findsOneWidget); // main version V2

    // 2 -> 3 servings: 500 g tilapia becomes 750 g
    final plus = find.widgetWithIcon(IconButton, Icons.add_rounded).first;
    await tester.ensureVisible(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(find.text('750 g'), findsOneWidget);
  });

  testWidgets('bottom navigation reaches invitations and accepts one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invitaciones').last);
    await tester.pumpAndSettle();
    expect(find.text('Aceptar'), findsOneWidget);

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya lo probé · Calificar'), findsWidgets);
  });
}
