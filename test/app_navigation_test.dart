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

    // Featured recipe sits below the dashboard and birthdays sections.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
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

  testWidgets('profile shows birthday, stats and contributions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Cumpleaños: 18 de marzo'), findsOneWidget);
    expect(find.text('Probadas y\ncalificadas'), findsOneWidget);
    expect(find.text('Categorías favoritas'), findsOneWidget);
  });

  testWidgets('another user profile shows favorite foods and birthday surprise', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final card = find.text('María Quispe');
    await tester.ensureVisible(card.first);
    await tester.pumpAndSettle();
    await tester.tap(card.first);
    await tester.pumpAndSettle();
    expect(find.text('Torta de chocolate'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing);
  });

  testWidgets('birthday food chip searches recipes and offers to create it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('María Quispe').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('María Quispe').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Dale una sorpresa'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Torta de chocolate'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos "Torta de chocolate" exacto. Recetas parecidas:'), findsOneWidget);
    expect(find.text('Copa de chocolate'), findsOneWidget);

    final create = find.text('Crear "Torta de chocolate"');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Torta de chocolate'), findsOneWidget);
  });
}
