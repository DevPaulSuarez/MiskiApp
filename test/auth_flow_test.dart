import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/app/app.dart';
import 'package:miski_app/core/demo/demo_backend.dart';
import 'package:miski_app/core/session/backend_providers.dart';
import 'package:miski_app/core/storage/token_storage.dart';

/// Starts signed out (no stored token) against the demo backend.
Widget signedOutApp() => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
    demoBackendProvider.overrideWithValue(DemoBackend(signedInAs: null)),
  ],
  child: const MiskiApp(),
);

Future<void> start(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  await tester.pumpWidget(signedOutApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a session the app asks to sign in, and wrong passwords are rejected', (tester) async {
    await start(tester);
    expect(find.text('Bienvenido a Miski'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'paul@miski.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'equivocada');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('El correo o la contraseña no son correctos.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), DemoBackend.password);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué cocinamos hoy?'), findsOneWidget);
  });

  testWidgets('sign up, then sign out from the profile', (tester) async {
    await start(tester);
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu nombre'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre y apellido'), 'Rosa Huamán');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'rosa@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña (mínimo 8 caracteres)'), 'secreta123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué cocinamos hoy?'), findsOneWidget);

    await tester.tap(find.byTooltip('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Rosa Huamán'), findsOneWidget);

    final logout = find.text('Cerrar sesión');
    await tester.scrollUntilVisible(logout, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('rosa@example.com'), findsOneWidget);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a Miski'), findsOneWidget);
  });
}
