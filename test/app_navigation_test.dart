import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/app/app.dart';
import 'package:miski_app/features/recipes/presentation/widgets/recipe_showcase.dart';

/// Scrolls the screen's main list until [finder] (a single widget) is built and visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('splash -> home -> recipe detail -> adjust servings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    expect(find.text('Miski'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué cocinamos hoy?'), findsOneWidget);

    // The app opens on the cookbook, which lists every dish.
    final ceviche = find.widgetWithText(RecipeRow, 'Ceviche peruano de tilapia');
    await scrollTo(tester, ceviche);
    await tester.tap(ceviche);
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

    await tester.tap(find.byTooltip('Invitaciones'));
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

    await tester.tap(find.byTooltip('Perfil'));
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

    await tester.tap(find.byTooltip('Inicio'));
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

    await tester.tap(find.byTooltip('Inicio'));
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

    final ceviche = find.widgetWithText(RecipeRow, 'Ceviche peruano de tilapia');
    await scrollTo(tester, ceviche);
    await tester.tap(ceviche);
    await tester.pumpAndSettle();
    expect(find.text('Versión de Carlos · Principal'), findsOneWidget);

    // The version tree is reachable from the first chip, whatever the number of versions.
    await tester.tap(find.widgetWithText(ActionChip, 'Árbol de versiones'));
    await tester.pumpAndSettle();
    expect(find.text('Basada en V2 de Carlos'), findsOneWidget); // María's V3 under Carlos's V2

    // Compare two versions: pickers show only who prepared each one.
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();
    expect(find.text('V1 · Tú'), findsOneWidget);
    expect(find.text('V3 · María'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
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
    // "Nueva receta" lives on Inicio.
    await tester.tap(find.byTooltip('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva receta').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la receta'), 'Ceviche de Paul');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ya existe "Ceviche peruano de tilapia"'), findsOneWidget);
    expect(find.text('Crear mi versión'), findsOneWidget);
  });

  testWidgets('home shortcuts open my recipes with search and new-recipe button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // Opens on the cookbook, with its four sections.
    expect(find.text('Destacadas'), findsOneWidget);
    expect(find.text('Rápidas y fáciles'), findsOneWidget);
    await scrollTo(tester, find.text('Populares de la semana 🔥'));
    expect(find.textContaining('esta semana'), findsWidgets);
    await scrollTo(tester, find.textContaining('Todas las recetas ('));

    await tester.tap(find.byTooltip('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva receta'), findsOneWidget);
    expect(find.text('Próximos cumpleaños 🎂'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recetas destacadas'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('reseñas'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Mi recetario'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('2 recetas propias'), findsOneWidget);
    await tester.tap(find.text('Mi recetario'));
    await tester.pumpAndSettle();
    expect(find.text('Mis recetas'), findsOneWidget);
    expect(find.text('Ceviche peruano de tilapia'), findsOneWidget);
    expect(find.text('Nueva receta'), findsOneWidget); // FAB

    await tester.enterText(find.byType(TextField), 'helado');
    await tester.pumpAndSettle();
    expect(find.text('Ceviche peruano de tilapia'), findsNothing);
    expect(find.text('Helado con fudge y caramelo'), findsOneWidget);
  });

  testWidgets('cookbook filters by time and has no add button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    await scrollTo(tester, find.text('Todas las recetas (8)'));
    await tester.scrollUntilVisible(find.byTooltip('Filtros'), -300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hasta 15 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hasta 15 min'));
    await tester.pumpAndSettle();
    final apply = find.textContaining(RegExp(r'^Ver \d+ recetas?$'));
    await tester.ensureVisible(apply);
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.text('Destacadas'), findsNothing);
    expect(find.text('Populares de la semana 🔥'), findsNothing);
    expect(find.text('Hasta 15 min'), findsOneWidget); // removable chip
    expect(find.textContaining('Todas las recetas ('), findsOneWidget);
    expect(find.text('Todas las recetas (8)'), findsNothing);
  });

  testWidgets('theme toggle switches between dark and light and keeps the page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Inicio'));
    await tester.pumpAndSettle();

    Color bg() => tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold).last)).scaffoldBackgroundColor;
    expect(bg(), const Color(0xFF000000)); // dark: black

    await tester.tap(find.byTooltip('Tema claro'));
    await tester.pumpAndSettle();
    expect(bg(), const Color(0xFFF5F0E8)); // light: cream
    expect(find.text('Accesos rápidos'), findsOneWidget); // still on Inicio

    await tester.tap(find.byTooltip('Tema oscuro'));
    await tester.pumpAndSettle();
    expect(bg(), const Color(0xFF000000));
  });

  testWidgets('bottom bar has the five original tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const ProviderScope(child: MiskiApp()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    for (final tab in ['Inicio', 'Recetario', 'Invitaciones', 'Favoritos', 'Perfil']) {
      expect(find.byTooltip(tab), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Favoritos'), findsOneWidget);
  });
}
