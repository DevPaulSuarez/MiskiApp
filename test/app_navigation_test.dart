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

  testWidgets('recipe shows other people\'s preparations and new recipe warns about existing dish', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ceviche peruano de tilapia').first);
    await tester.pumpAndSettle();
    expect(find.text('Versión de Carlos · Principal'), findsOneWidget);

    // The version tree is reachable from the first chip, whatever the number of versions.
    await tester.tap(find.widgetWithText(ActionChip, 'Árbol de versiones'));
    await tester.pumpAndSettle();
    expect(find.text('Basada en V2 de Carlos'), findsOneWidget); // María's V3 under Carlos's V2
    await tester.pageBack();
    await tester.pumpAndSettle();

    final section = find.text('Otras formas de prepararlo (3)');
    await tester.scrollUntilVisible(section, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Tu versión · V1'), findsOneWidget);
    expect(find.text('Versión de María · V3'), findsOneWidget);

    // Viewing Carlos's V2 while I have V1: the app asks whether to continue my own version.
    await tester.tap(find.text('Nueva versión'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar mi versión · V1'), findsOneWidget);
    await tester.tap(find.text('Continuar mi versión · V1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Partes de una copia de V1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // New recipe named like an existing dish suggests creating your version instead.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nueva receta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva receta').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la receta'), 'Ceviche de Paul');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ya existe "Ceviche peruano de tilapia"'), findsOneWidget);
    expect(find.text('Crear mi versión'), findsOneWidget);
  });
}
