// Drives the real app against a running API (see README):
//   flutter test integration_test -d <device> --dart-define=MISKI_API_URL=http://<ip>:8000/api/v1
// Needs the demo data (./scripts/dev.sh --fresh). Writes a comment.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miski_app/app/app.dart';
import 'package:miski_app/core/config/app_config.dart';
import 'package:miski_app/core/session/backend_providers.dart';
import 'package:miski_app/core/storage/token_storage.dart';
import 'package:miski_app/features/recipes/presentation/widgets/recipe_showcase.dart';

Future<void> settle(WidgetTester tester, [int seconds = 4]) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> centerOn(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.4);
  await settle(tester, 1);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in, open a dish and comment against the live API', (tester) async {
    expect(AppConfig.isDemo, isFalse, reason: 'Run with --dart-define=MISKI_API_URL=...');
    await tester.pumpWidget(
      ProviderScope(overrides: [tokenStorageProvider.overrideWithValue(MemoryTokenStorage())], child: const MiskiApp()),
    );
    await settle(tester);
    expect(find.text('Bienvenido a Miski'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'paul@miski.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'miski1234');
    await tester.tap(find.text('Iniciar sesión'));
    await settle(tester);
    expect(find.text('¿Qué cocinamos hoy?'), findsOneWidget);

    final ceviche = find.widgetWithText(RecipeRow, 'Ceviche peruano de tilapia');
    await tester.scrollUntilVisible(ceviche, 300, scrollable: find.byType(Scrollable).first);
    await centerOn(tester, ceviche); // out from under the floating bar
    await tester.tap(ceviche);
    await settle(tester, 2);
    expect(find.text('Más limón, menos cebolla'), findsOneWidget);

    final stamp = 'Prueba en vivo ${DateTime.now().millisecondsSinceEpoch}';
    final comments = find.textContaining('Comentarios (');
    await tester.scrollUntilVisible(comments, 300, scrollable: find.byType(Scrollable).first);
    await centerOn(tester, comments);
    await tester.tap(comments);
    await settle(tester, 2);
    await tester.enterText(find.byType(TextField).last, stamp);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settle(tester);
    expect(find.text(stamp), findsOneWidget);
  });
}
