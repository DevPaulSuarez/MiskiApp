# Miski

Plataforma de recetas con versiones: cada plato existe una sola vez y cada persona aporta su forma de prepararlo
(versiones con su nombre), invita a sus amigos a probarlo y recibe calificaciones.

| Parte | Tecnología | Carpeta |
|---|---|---|
| App móvil | Flutter 3 · Riverpod 3 · GoRouter | `lib/` |
| API | Laravel 13 · Sanctum (tokens) | `backend/` |
| Base de datos | MySQL | `backend/database`, migraciones en cada módulo |

La arquitectura (módulos, cómo agregar uno nuevo, endpoints y modelo de datos) está en
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Ejecutar en local

Requisitos: PHP 8.4+, Composer, MySQL (Homebrew), Flutter.

```bash
./scripts/dev.sh            # levanta MySQL + API en http://<ip-de-tu-wifi>:8000
./scripts/dev.sh --fresh    # borra la base y vuelve a cargar los datos demo
```

En otra terminal, con el celular en la misma WiFi:

```bash
flutter run --dart-define=MISKI_API_URL=http://<ip-de-tu-wifi>:8000/api/v1
./scripts/build-apk.sh      # o genera ~/Desktop/Miski.apk apuntando a esta Mac
```

Cuentas demo (todas con la contraseña `miski1234`): `paul@miski.test`, `carlosm@miski.test`,
`mariaq@miski.test`, `luciar@miski.test`, `diegot@miski.test`. También puedes registrarte desde la app.

**Modo demo sin servidor:** si compilas sin `MISKI_API_URL`, la app usa un backend en memoria con los mismos
datos de ejemplo (sirve para las pruebas y para mostrar la app sin conexión; nada se guarda).

## Pruebas

```bash
flutter analyze && flutter test                    # app (widgets, sesión, contrato JSON)
cd backend && php artisan test                     # API (reglas de negocio)
dart run tool/api_smoke_test.dart                  # punta a punta contra la API corriendo (crea datos)
```

## Servidor

Por ahora Miski corre solo en local (tu Mac + celulares en la misma WiFi). Cuando haga falta publicarlo, un
hosting compartido con PHP y MySQL basta: es un Laravel estándar, sin colas ni procesos aparte. En ese momento
habrá que servirlo con HTTPS y quitar `android:usesCleartextTraffic` del `AndroidManifest.xml`.

## Ramas y commits

`main` (estable) · `develop` (integración) · `feature/*`. Mensajes con
[Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`...).
