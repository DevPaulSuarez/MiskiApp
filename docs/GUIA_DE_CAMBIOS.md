# Guía de cambios de Miski

Índice práctico para modificar la app y el backend **sin romper nada**. Para cada pantalla y cada endpoint dice
qué archivo tocar, qué pasa ahí y qué más se ve afectado. La explicación general de la arquitectura está en
[ARCHITECTURE.md](ARCHITECTURE.md); esta guía es el "dónde toco".

## Índice

1. [Cómo viaja un dato (de la pantalla a MySQL y de vuelta)](#1-cómo-viaja-un-dato)
2. [Contratos que NO se deben romper](#2-contratos-que-no-se-deben-romper)
3. [Pantallas de la app](#3-pantallas-de-la-app)
4. [Estado de la app (providers)](#4-estado-de-la-app-providers)
5. [Backend: endpoints y dónde está cada cosa](#5-backend-endpoints-y-dónde-está-cada-cosa)
6. [Reglas de negocio: dónde vive cada una](#6-reglas-de-negocio-dónde-vive-cada-una)
7. [Notificaciones](#7-notificaciones)
8. [Aspecto visual (colores, tema, barra inferior)](#8-aspecto-visual)
9. [Recetas de cambios frecuentes (paso a paso)](#9-recetas-de-cambios-frecuentes)
10. [Datos demo y semillas](#10-datos-demo-y-semillas)
11. [Pruebas: qué cubre cada una](#11-pruebas)
12. [Checklist antes de hacer commit](#12-checklist-antes-de-hacer-commit)

---

## 1. Cómo viaja un dato

```
Pantalla (presentation/screens)
   │  lee:   ref.watch(algoProvider)                (síncrono, ya está en memoria)
   │  guarda: ref.read(algoProvider.notifier).accion(...)
   ▼
Provider de estado (presentation/providers)        ← arranca desde AppSnapshot (GET /sync)
   │  llama al contrato
   ▼
Contrato (domain/..._repository.dart)               ← interfaz abstracta
   │  implementado por DOS clases:
   ├─► data/api_*_repository.dart  → ApiClient → HTTP /api/v1/...   (modo real)
   └─► core/demo/demo_backend.dart                                 (modo demo y pruebas)
          ▼
Backend: routes.php → Controller → FormRequest (valida) → Model/Service → MySQL
          └─► Resource (arma el JSON de respuesta) ──► data/*_json.dart lo convierte en entidad
```

- **Al iniciar sesión** se descarga todo con `GET /sync` (`lib/core/session/api_sync_repository.dart` ↔
  `backend/app/Modules/Sync/Http/Controllers/SyncController.php`) y se guarda en `AppSnapshot`.
- **Al guardar** algo, el provider espera la respuesta del servidor y actualiza su lista con lo que devolvió
  (los favoritos son optimistas: cambian primero y se revierten si falla).
- **Al refrescar** (deslizar hacia abajo, volver a la app, o cuando llegan notificaciones nuevas cada 45 s) se
  vuelve a pedir `/sync` completo: `lib/app/router/activity_sync.dart`.
- **Modo demo**: si se compila sin `--dart-define=MISKI_API_URL=...`, todo lo sirve `DemoBackend` en memoria
  (`lib/core/config/app_config.dart`, `lib/core/session/backend_providers.dart`).

---

## 2. Contratos que NO se deben romper

Estas son las uniones entre app y backend. Si cambias un lado **tienes que cambiar el otro en el mismo commit**.

| Contrato | Lado app | Lado backend | Qué se rompe si no coinciden |
|---|---|---|---|
| **Nombres de campos JSON** (`snake_case`) | `lib/features/*/data/*_json.dart`, `api_*_repository.dart` | `app/Modules/*/Http/Resources/*.php` y `Http/Requests/*.php` | La app falla al leer (`null` no es `String`) y la pantalla queda en error / splash |
| **Ids como texto** | todas las entidades usan `String id`; al enviar se convierte con `_id()` (`int.tryParse`) | Resources hacen `(string) $this->id`; Requests validan `integer` | `as String` revienta si llega un número |
| **Unidades de medida** | `lib/features/recipes/domain/entities/measure_unit.dart` (`gram`, `kilogram`, ...) | `app/Modules/Catalog/Enums/MeasureUnit.php` | `MeasureUnit.values.byName` lanza error y no carga ninguna receta |
| **Dificultad** (`easy/medium/hard`) | `Difficulty` en `recipes/domain/entities/recipe.dart` | `app/Modules/Recipes/Enums/Difficulty.php` | igual que arriba |
| **Estado del plato** (`active/archived`) | `RecipeStatus` en `recipe.dart` | `app/Modules/Recipes/Enums/RecipeStatus.php` | igual |
| **Estado de invitación** (`pending/accepted/rejected/completed`) | `InvitationStatus` en `social/domain/social_entities.dart` | `app/Modules/Social/Enums/InvitationStatus.php` | igual |
| **Rutas dentro de notificaciones** (`/version/12`, `/invitations`...) | rutas de `lib/app/router/app_router.dart` | textos en `app/Modules/Notifications/Listeners/SendActivityNotifications.php` | tocar la notificación lleva a una pantalla inexistente |
| **Forma de `/sync`** | `lib/core/session/api_sync_repository.dart` + `app_snapshot.dart` | `SyncController.php` | la app no arranca (se queda en el splash) |
| **Fechas** ISO 8601 UTC; cumpleaños `AAAA-MM-DD` | `parseDate()` en `recipe_json.dart`, `SocialJson.user` | `toIso8601ZuluString()`, `toDateString()` | fechas corridas o error de parseo |
| **Errores** `{message, errors}` en español | `lib/core/network/api_client.dart` (`_error`) | Laravel por defecto + `backend/lang/es/*.php` | se muestran mensajes genéricos |
| **Interfaz de repositorio** | `domain/*_repository.dart` | — | si agregas un método, `DemoBackend` y la clase `Api*` deben implementarlo o no compila |

**Regla de oro:** agregar campos es seguro si la app los lee con valor por defecto (`j['x'] as String? ?? ''`).
Renombrar o quitar campos **no** es seguro: hazlo en ambos lados a la vez.

---

## 3. Pantallas de la app

Todas las rutas se registran en **`lib/app/router/app_router.dart`**. Las 5 pestañas de la barra inferior son
`StatefulShellBranch` (mismo orden que `_AppShell._items`); el resto se abren encima con `context.push`.

### Acceso

| Ruta | Archivo | Qué hace | Lee / llama | Backend |
|---|---|---|---|---|
| `/splash` | `lib/features/splash/presentation/splash_screen.dart` | Logo mientras carga la sesión; si no hay servidor, ofrece reintentar | `sessionProvider` | `GET /sync` |
| `/login` | `lib/features/auth/presentation/login_screen.dart` | Correo + contraseña | `sessionProvider.notifier.login` | `POST auth/login` → `AuthController@login`, `LoginRequest` |
| `/register` | `lib/features/auth/presentation/register_screen.dart` | Nombre, correo, contraseña, cumpleaños opcional | `sessionProvider.notifier.register` | `POST auth/register` → `RegisterRequest` |
| (widgets) | `lib/features/auth/presentation/auth_widgets.dart` | `AuthScaffold`, `PasswordField` compartidos por login y registro | — | — |

La **redirección** (sin sesión → `/login`, con sesión → `/recipes`) está en el `redirect:` de `app_router.dart`.
Si agregas una pantalla pública (sin login), añádela a la condición `onAuth` de ahí.

### Pestañas (barra inferior)

| # | Ruta | Archivo | Qué muestra | Providers principales |
|---|---|---|---|---|
| 0 | `/` | `lib/features/home/presentation/home_screen.dart` | "Inicio": saludo, accesos rápidos, próximos cumpleaños, destacados | `featuredRecipesProvider`, `userByIdProvider` |
| | | `home/presentation/widgets/dashboard_shortcuts.dart` | Tarjetas: nueva receta, mis recetas, invitaciones, favoritos | `activeRecipesProvider`, `favoritesProvider` |
| | | `home/presentation/widgets/upcoming_birthdays.dart` | Cumpleaños cercanos de amigos | `upcomingBirthdaysProvider` |
| 1 | `/recipes` | `lib/features/recipes/presentation/screens/cookbook_screen.dart` | Recetario: buscador, categorías, filtros, mejores de la semana, lista | `cookbookFiltersProvider` y `filteredRecipesProvider` (definidos **en este mismo archivo**), `weeklyBestProvider` |
| 2 | `/invitations` | `lib/features/social/presentation/screens/invitations_screen.dart` | Recibidas / enviadas; aceptar, rechazar, ir a calificar | `invitationsProvider` → `PATCH invitations/{id}` |
| 3 | `/favorites` | `lib/features/recipes/presentation/screens/favorites_screen.dart` | Platos con ♥ | `favoritesProvider`, `recipesProvider` |
| 4 | `/profile` | `lib/features/profile/presentation/profile_screen.dart` | Perfil propio: estadísticas, versiones, comidas favoritas, ajustes, cerrar sesión | `usersProvider`, `versionsProvider`, `ratingsProvider` |

Para **cambiar el orden o agregar una pestaña**: mover/añadir la `StatefulShellBranch` **y** el
`MiskiNavItem` correspondiente en `_AppShell._items` (mismo índice). Si no coinciden, el icono abre otra pestaña.

### Recetas

| Ruta | Archivo | Qué hace | Guarda con | Backend |
|---|---|---|---|---|
| `/search?q=` | `recipes/presentation/screens/search_screen.dart` | Busca por nombre, ingrediente o categoría; si no existe, ofrece crearlo | — | (local) |
| `/my-recipes` | `recipes/presentation/screens/my_recipes_screen.dart` | Platos y versiones del usuario | — | (local) |
| `/recipe/:id` | `recipes/presentation/screens/recipe_detail_screen.dart` | Detalle del plato: versión principal, porciones, costo, criterios, otras preparaciones, acciones (invitar, calificar, comentar, mi versión, archivar, principal) | `recipesProvider.notifier.setMainVersion / toggleArchive` | `PATCH recipes/{id}` |
| `/version/:vid` | mismo archivo (`RecipeDetailScreen.forVersion`) | Igual, pero mostrando una versión concreta | | |
| `/recipe-new?name=` | `recipes/presentation/screens/version_editor_screen.dart` | Crear plato nuevo + V1 (pestañas Datos / Ingredientes / Pasos). Detecta platos parecidos (`_SimilarDishesHint`, `DishMatcher`) | `recipesProvider.notifier.createDish` (+ `uploadImage` si hay foto) | `POST uploads/images`, `POST recipes` |
| `/version/:vid/derive` | mismo editor con `parentVersionId` | Nueva versión basada en otra (nunca edita la original) | `versionsProvider.notifier.add` | `POST recipes/{id}/versions` |
| `/recipe/:id/versions` | `recipes/presentation/screens/version_history_screen.dart` | Árbol/lista de versiones; elegir 2 para comparar | — | (local) |
| `/recipe/:id/compare?a=&b=` | `recipes/presentation/screens/compare_versions_screen.dart` | Diferencias de ingredientes, pasos, costo y calificación | — | (local) |
| `/version/:vid/costs?servings=` | `recipes/presentation/screens/costs_screen.dart` | Costo total y por porción (**oculta por ahora**, ver §9.10) | — | (local, `CostCalculator`) |

Widgets de recetas reutilizados en varias pantallas:

- `recipes/presentation/widgets/recipe_card.dart` — `FavoriteButton` (♥) y `RecipeListTile`.
- `recipes/presentation/widgets/recipe_showcase.dart` — `FeaturedRecipeCard`, `CompactRecipeCard`, `RecipeRow` y
  los providers `featuredRecipesProvider` / `weeklyBestProvider`. **Lo usan Inicio y Recetario**: un cambio aquí
  se ve en ambos.
- `recipes/presentation/widgets/ingredient_line_sheet.dart` — hoja para agregar/editar un ingrediente (cantidad,
  unidad, nota, compra). Crea ingredientes nuevos con `ingredientsProvider.notifier.findOrCreate` →
  `POST ingredients`.

Cálculos puros (sin Flutter, fáciles de probar) en `lib/features/recipes/domain/services/`:

| Archivo | Qué calcula |
|---|---|
| `recipe_calculators.dart` | `ServingCalculator` (escalar porciones), `CostCalculator` (costos), `VersionComparator` (diferencias) |
| `recipe_filters.dart` | Filtros del recetario y "mejores del periodo" |
| `dish_matcher.dart` | Detección de platos duplicados por nombre e ingredientes (umbral 0.7) y "preparaciones por autor" |

### Social

| Ruta | Archivo | Qué hace | Guarda con | Backend |
|---|---|---|---|---|
| `/version/:vid/invite` | `social/presentation/screens/invite_screen.dart` | Elegir amigos y mensaje | `invitationsProvider.notifier.send` | `POST invitations` |
| `/version/:vid/rate?inv=` | `social/presentation/screens/rate_screen.dart` | Estrellas + 4 criterios + comentario | `ratingsProvider.notifier.rate` | `POST ratings` |
| `/version/:vid/comments` | `social/presentation/screens/comments_screen.dart` | Comentarios de una versión | `commentsProvider.notifier.add` | `POST versions/{id}/comments` |
| `/notifications` | `social/presentation/screens/notifications_screen.dart` | Lista de avisos; tocar uno navega a su `route` | `notificationsProvider.notifier.markRead / markAllRead` | `POST notifications/{id}/read`, `read-all` |
| (widget) | `social/presentation/widgets/notifications_action.dart` | Campanita con contador de no leídas | `unreadCountProvider` | |

### Perfil

| Ruta | Archivo | Qué hace | Guarda con | Backend |
|---|---|---|---|---|
| `/user/:id` | `profile/presentation/profile_screen.dart` (con `userId`) | Perfil público de otra persona (cumpleaños, comidas favoritas para sorprenderla) | — | — |
| `/profile/edit` | `profile/presentation/screens/edit_profile_screen.dart` | Nombre, usuario, bio, cumpleaños, categorías favoritas | `usersProvider.notifier.updateMe` | `PATCH me` → `UpdateProfileRequest` |
| (hoja) | `profile/presentation/widgets/favorite_foods_sheet.dart` | Editar "comidas favoritas" (platos que le gustan a la persona) | `usersProvider.notifier.setFavoriteFoods` | `PATCH me` |

### Compartido

- `lib/shared/widgets/common_widgets.dart` — `RecipeImage`, `StarRating`, `StarInput`, `SectionHeader`,
  `EmptyState`, `UserAvatar`, `InfoPill`, `StatusBadge`. **Se usan en casi todas las pantallas**; cambia con
  cuidado la firma (parámetros).
- `lib/shared/widgets/async_action.dart` — `runQuietly` y ayudas para ejecutar acciones mostrando errores en un
  SnackBar.
- `lib/shared/widgets/theme_toggle.dart` — botón/selector claro-oscuro.

---

## 4. Estado de la app (providers)

| Provider | Archivo | Contiene | Se modifica con |
|---|---|---|---|
| `sessionProvider` | `lib/core/session/session_controller.dart` | Usuario + `AppSnapshot` | `login`, `register`, `logout`, `refresh`, `expire` |
| `snapshotProvider`, `currentUserIdProvider`, `currentEmailProvider` | mismo | Atajos a la sesión | — |
| `recipesProvider`, `activeRecipesProvider`, `recipeByIdProvider` | `lib/features/recipes/presentation/providers/recipe_providers.dart` | Platos | `createDish`, `setMainVersion`, `toggleArchive` |
| `versionsProvider`, `versionByIdProvider`, `versionsOfRecipeProvider` | mismo | Versiones | `add` |
| `ingredientsProvider`, `ingredientByIdProvider`, `categoriesProvider` | mismo | Catálogo | `findOrCreate` |
| `favoritesProvider` | mismo | Ids de platos con ♥ | `toggle` (optimista) |
| `preparationsProvider`, `basedOnLabelProvider`, `myLatestVersionProvider` | `recipes/presentation/providers/preparation_providers.dart` | "Versión de María", "Basada en V2 de Carlos" | — |
| `usersProvider`, `userByIdProvider`, `upcomingBirthdaysProvider` | `lib/features/social/presentation/providers/social_providers.dart` | Personas | `updateMe`, `setFavoriteFoods` |
| `invitationsProvider`, `friendIdsProvider` | mismo | Invitaciones | `send`, `answer` |
| `ratingsProvider`, `ratingSummaryProvider`, `recipeRatingSummaryProvider` | mismo | Calificaciones y promedios (fiable con ≥ 3) | `rate` |
| `commentsProvider`, `commentsOfVersionProvider` | mismo | Comentarios | `add` |
| `notificationsProvider`, `myNotificationsProvider`, `unreadCountProvider` | mismo | Avisos | `reload`, `markRead`, `markAllRead` |
| `appBrightnessProvider` | `lib/app/theme/theme_mode_provider.dart` | Claro / oscuro | `toggle` |
| `*RepositoryProvider` | `features/*/data/*_data_providers.dart` | Elige HTTP o demo (`pickRepository`) | — |

---

## 5. Backend: endpoints y dónde está cada cosa

Todas las rutas van bajo `/api/v1` y (salvo registro/login) piden token. Cada módulo está en
`backend/app/Modules/<Módulo>/` con la misma forma:

```
routes.php              rutas del módulo (se montan solas)
Http/Controllers/       qué hace cada endpoint
Http/Requests/          validación de entrada (mensajes en backend/lang/es/validation.php)
Http/Resources/         forma del JSON de salida  ← contrato con la app
Models/                 tablas y relaciones
Database/Migrations/    estructura de tablas
Events/ Listeners/      comunicación entre módulos
*ServiceProvider.php    registra el módulo (y sus listeners en $listen)
```

| Endpoint | Controlador | Validación | Respuesta (Resource) | Lo usa en la app |
|---|---|---|---|---|
| `POST auth/register` | `Identity/Http/Controllers/AuthController@register` | `RegisterRequest` | `{token, user: MeResource}` | `ApiAuthRepository.register` |
| `POST auth/login` | `AuthController@login` | `LoginRequest` | idem | `ApiAuthRepository.login` |
| `GET auth/me`, `POST auth/logout` | `AuthController@me/logout` | — | `MeResource` | `logout` |
| `PATCH me` | `Identity/.../ProfileController@update` | `UpdateProfileRequest` | `MeResource` | `ApiProfileRepository.updateProfile` |
| `GET users`, `users/{id}` | `ProfileController@index/show` | — | `UserResource` (sin correo) | (vía `/sync`) |
| `GET sync` | `Sync/Http/Controllers/SyncController` | — | todo junto | `ApiSyncRepository.fetch` |
| `GET categories`, `GET/POST ingredients` | `Catalog/.../CatalogController` | en el controlador | `CategoryResource`, `IngredientResource` | `ApiCatalogRepository` |
| `GET/POST recipes`, `GET/PATCH recipes/{id}` | `Recipes/.../RecipeController` | `StoreRecipeRequest` + `VersionRules` | `RecipeResource`, `VersionResource` | `ApiRecipeRepository` |
| `POST recipes/{id}/versions`, `GET versions/{id}` | `RecipeController@storeVersion/showVersion` | `StoreVersionRequest` + `VersionRules` | `VersionResource` | `addVersion` |
| `GET/PUT/DELETE favorites/{recipe}` | `Recipes/.../FavoriteController` | — | lista de ids | `setFavorite` |
| `POST uploads/images` | `Recipes/.../UploadController` | jpg/png/webp ≤ 6 MB | `{path, url}` | `uploadImage` |
| `GET/POST invitations`, `PATCH invitations/{id}` | `Social/.../InvitationController` | en el controlador | `InvitationResource` | `ApiSocialRepository` |
| `POST ratings` | `Social/.../RatingController` | en el controlador | `{rating, comment, invitation}` | `rate` |
| `GET/POST versions/{id}/comments` | `Social/.../CommentController` | en el controlador | `CommentResource` | `addComment` |
| `GET notifications`, `POST .../read`, `read-all` | `Notifications/.../NotificationController` | — | `NotificationResource` | `fetchNotifications` |

Lógica que no está en controladores:

- `Recipes/Services/VersionPublisher.php` — crea plato + V1 y nuevas versiones en una transacción, asigna el
  número correlativo bloqueando la fila, y dispara `VersionPublished`.
- `Recipes/Models/RecipeVersion.php` — **impide actualizar** una versión publicada (`updating` lanza excepción).
- `Recipes/Policies/RecipePolicy.php` — solo el autor gestiona el plato.
- `Catalog/Enums/MeasureUnit.php` — unidades y compatibilidad (masa / volumen / unidades).
- `config/modules.php` — lista de módulos activos (quitar una línea apaga un módulo).
- `bootstrap/app.php` — middleware de la API y manejo de errores JSON.
- `app/Providers/AppServiceProvider.php` — límites de intentos: `auth` (10/min por IP, login y registro) y `api` (120/min por usuario).

---

## 6. Reglas de negocio: dónde vive cada una

Las reglas importantes están **dos veces**: en el servidor (la que manda) y en la app (para mostrar/ocultar
botones y en `DemoBackend`). Si cambias una regla, cambia los tres sitios.

| Regla | Servidor (manda) | App (UI) | Demo |
|---|---|---|---|
| Solo el autor cambia versión principal / archiva | `RecipePolicy`, `RecipeController@update` | `RecipesNotifier.canManage` en `recipe_providers.dart`; botones en `recipe_detail_screen.dart` | `DemoBackend.updateRecipe` |
| Las versiones no se editan, se derivan | `RecipeVersion::booted`, `VersionPublisher` | `version_editor_screen.dart` (siempre crea) | `addVersion` |
| Aviso al autor con ingredientes agregados/quitados | `SendActivityNotifications::versionPublished`, `VersionPublished::ingredientChanges` | — | `DemoBackend.addVersion` |
| Unidad de compra compatible | `VersionRules::checkUnits` | `ingredient_line_sheet.dart` (solo ofrece compatibles) | — |
| Ingredientes sin duplicados | `CatalogController@storeIngredient` | `IngredientsNotifier.findOrCreate` | `findOrCreateIngredient` |
| Detección de plato duplicado | — (solo sugerencia) | `dish_matcher.dart`, `_SimilarDishesHint` | — |
| No invitar dos veces a la misma persona a la misma versión mientras su invitación siga abierta (pendiente o aceptada sin calificar) | `InvitationController::rejectDuplicates`, scope `Invitation::open` | `openInviteesProvider` en `social_providers.dart`; filas bloqueadas en `invite_screen.dart` | `sendInvitations` |
| Solo el invitado responde, una vez | `InvitationController@update` | `invitations_screen.dart` | `answerInvitation` |
| Para calificar con invitación hay que aceptarla; una calificación por invitación | `RatingController::checkInvitation` | `RatingsNotifier.canRateInvitation`, `rate_screen.dart` | `rate` |
| No calificar tu propia versión; una vez por versión | `RatingController@store` | botones en `recipe_detail_screen.dart` | `rate` |
| Promedio "fiable" con ≥ 3 calificaciones | — | `RatingSummary.minReliableCount` en `social_entities.dart` | — |
| Archivados ocultos salvo invitación | `SyncController` (consulta de `recipes`) | `activeRecipesProvider` | `fetch` |
| Límites de validación (porciones 1–100, máx. 60 ingredientes/pasos...) | `VersionRules::rules` | validaciones del editor | — |

---

## 7. Notificaciones

- **Se crean** en `backend/app/Modules/Notifications/Listeners/SendActivityNotifications.php` (título, texto y
  `route`). Cambiar un texto de aviso = editar ese archivo. Nadie recibe aviso de sus propias acciones.
- **Qué eventos escucha**: `$listen` en `NotificationsServiceProvider.php`. Los eventos están en
  `Recipes/Events` y `Social/Events` y se disparan desde `VersionPublisher` y los controladores de Social.
- **El `route`** debe ser una ruta válida de `app_router.dart` (ver §2). Hoy se usan: `/version/{id}`,
  `/version/{id}/comments`, `/invitations`.
- **En la app**: `notifications_screen.dart` navega con `context.go` a pestañas y `context.push` al resto;
  `ActivitySync` sondea cada `AppConfig.pollInterval` (45 s).
- Para agregar un aviso nuevo: crear evento en el módulo que actúa → dispararlo (`event(new ...)`) → añadir método
  en el listener → registrarlo en `$listen`. Recetas/Social no deben importar nada de Notificaciones.

---

## 8. Aspecto visual

| Qué cambiar | Archivo | Cuidado |
|---|---|---|
| Colores de marca y roles (fondo, tarjeta, acento, peligro...) | `lib/app/theme/app_colors.dart` | Las pantallas usan **roles** (`AppColors.surface`, `accent`...), nunca hex. Cambia el rol, no las pantallas. Hay paleta `_dark` y `_light`: cambia ambas |
| Tipografía, botones, inputs, AppBar, chips | `lib/app/theme/app_theme.dart` | Afecta a toda la app |
| Claro / oscuro por defecto | `lib/app/theme/theme_mode_provider.dart` | |
| Barra inferior (forma, tamaño, animación) | `lib/app/router/miski_nav_bar.dart` | Constantes `_barHeight`, `_circle`, `_rise`... arriba de la clase |
| Iconos y nombres de pestañas | `_AppShell._items` en `app_router.dart` | Mismo orden que las ramas |
| Icono de la app / nombre | `android/app/src/main/res/mipmap-*`, `ios/Runner/Assets.xcassets/AppIcon.appiconset`, `android/app/src/main/AndroidManifest.xml` (`android:label`), `ios/Runner/Info.plist` | |

---

## 9. Recetas de cambios frecuentes

### 9.1 Cambiar solo cómo se ve una pantalla
1. Abre el archivo de la tabla de §3. Solo toca widgets; no cambies providers.
2. Usa colores de `AppColors` y widgets de `common_widgets.dart`.
3. `flutter analyze && flutter test` (`app_navigation_test.dart` busca textos concretos: si cambias un título o
   botón que aparece ahí, actualiza la prueba).

### 9.2 Agregar un campo nuevo (ej. "origen" del plato)
Orden recomendado, de abajo hacia arriba:
1. **Migración nueva** en `backend/app/Modules/Recipes/Database/Migrations/` (`php artisan make:migration` y
   muévela ahí). **Nunca edites una migración ya ejecutada**; crea otra con `->nullable()` o valor por defecto.
2. `Models/Recipe.php`: agregar a `$fillable` (y `casts` si aplica).
3. `Http/Requests/StoreRecipeRequest.php`: regla de validación (`nullable` para no romper apps viejas).
4. `Http/Resources/RecipeResource.php`: agregar `'origin' => $this->origin`.
5. `php artisan test`.
6. App: campo en `Recipe` (`recipe.dart`, también en `copyWith`), leerlo en `RecipeJson.recipe` **con valor por
   defecto** (`j['origin'] as String? ?? ''`), enviarlo en `ApiRecipeRepository.createDish` / `DishDraft`.
7. `DemoBackend.createDish` y, si quieres verlo en demo, `lib/core/mock/mock_data.dart`.
8. Mostrarlo en la pantalla. `flutter analyze && flutter test`.

### 9.3 Agregar una pantalla nueva
1. Crear `lib/features/<módulo>/presentation/screens/mi_pantalla.dart` (`ConsumerWidget`).
2. Registrar `GoRoute(path: '/mi-ruta', ...)` en `app_router.dart` (fuera del shell si se abre encima; dentro
   como rama nueva si es pestaña — ver §3).
3. Navegar con `context.push('/mi-ruta')`.
4. Añadirla a `test/app_navigation_test.dart` si es importante.

### 9.4 Agregar un endpoint nuevo
1. Ruta en `backend/app/Modules/<Módulo>/routes.php` dentro de `auth:sanctum`.
2. Método en el controlador; validación con un `FormRequest`; respuesta con un `Resource` (ids como texto).
3. Prueba en `backend/tests/Feature/`.
4. App: método en la interfaz `domain/*_repository.dart` → implementarlo en `data/api_*_repository.dart`
   **y en `DemoBackend`** (si falta, no compila) → acción en el provider → usarla en la pantalla.
5. Documentarlo en la tabla de API de `ARCHITECTURE.md`.

### 9.5 Agregar una unidad de medida / dificultad / estado
Agrégala en el enum de la app **y** en el del backend con el mismo nombre (§2). Para unidades, define su
dimensión y factor en ambos (`measure_unit.dart` y `MeasureUnit.php`). Si sale primero el backend, las apps
viejas fallarán al leer recetas con la unidad nueva: publica ambos juntos.

### 9.6 Cambiar una regla de negocio
Cámbiala en los tres sitios de §6 (servidor, UI, demo) y ajusta la prueba correspondiente
(`backend/tests/Feature/*Test.php` y `test/recipe_permissions_test.dart`).

### 9.7 Agregar una categoría
Es dato, no código: `backend/database/seeders/CatalogSeeder.php` (nombre + emoji, el orden define `position`).
Luego `php artisan db:seed`. Para el modo demo, también en `mock_data.dart`.

### 9.8 Agregar un módulo completo (Compras, Planificador...)
Ver "Agregar un módulo" en [ARCHITECTURE.md](ARCHITECTURE.md): carpeta en `app/Modules`, provider que extienda
`ModuleServiceProvider`, registrarlo en `config/modules.php`; en la app `features/<módulo>/{domain,data,presentation}`,
rutas en `app_router.dart` y, si hace falta en el arranque, su parte en `AppSnapshot` + `SyncController` +
`ApiSyncRepository` + `DemoBackend.fetch`.

### 9.9 Cambiar la URL del servidor
No está en el código: se pasa al compilar con `--dart-define=MISKI_API_URL=http://IP:8000/api/v1`
(`scripts/build-apk.sh` lo hace solo). En el backend, `APP_URL` de `backend/.env` define las URLs de las fotos.

### 9.10 Volver a mostrar precios y costos
Por ahora **todo lo de precios y costos está oculto** en la app, pero sigue en el código y en la API (los
precios guardados no se pierden). Lo controla `AppConfig.showCosts` en `lib/core/config/app_config.dart`.

- Probarlo sin tocar código: `flutter run --dart-define=MISKI_SHOW_COSTS=true` (o agrégalo en
  `scripts/build-apk.sh`).
- Activarlo para siempre: cambia el valor por defecto en `app_config.dart` y borra `test/costs_hidden_test.dart`
  (esa prueba verifica que estén ocultos).

Qué se oculta: la sección "Costos" y el criterio "Costo/calidad" del detalle (`recipe_detail_screen.dart`), la
ruta `/version/:vid/costs` (`costs_screen.dart`), los costos al comparar versiones, el costo por persona en el
historial, el precio de compra al agregar un ingrediente (`ingredient_line_sheet.dart`; si una línea ya tenía
precio, se conserva al editarla) y el criterio "Costo / calidad" al calificar (se envía en 0, y los promedios
ignoran los ceros). Antes de activarlo, cambia la moneda de `$` a `S/` en `Fmt.money` (`lib/core/utils/formatters.dart`).

---

## 10. Datos demo y semillas

| Archivo | Para qué | Si lo cambias |
|---|---|---|
| `lib/core/mock/mock_data.dart` | Datos de ejemplo del modo demo y de las pruebas de la app | Algunas pruebas cuentan elementos o buscan nombres concretos: córrelas |
| `lib/core/demo/demo_backend.dart` | Backend en memoria que imita las reglas del servidor | Debe implementar todas las interfaces de repositorio |
| `backend/database/seeders/data/demo.json` | Los mismos datos demo para MySQL. **Se genera**, no se edita a mano: `dart run tool/export_mock_data.dart > backend/database/seeders/data/demo.json` | |
| `backend/database/seeders/CatalogSeeder.php` | Categorías e ingredientes base (también en producción) | |
| `backend/database/seeders/DemoSeeder.php`, `DemoData.php` | Carga `demo.json` (solo fuera de producción) | |

`./scripts/dev.sh --fresh` borra la base y la vuelve a llenar con todo esto.

---

## 11. Pruebas

| Comando | Archivo | Qué verifica |
|---|---|---|
| `flutter test` | `test/costs_hidden_test.dart` | Que precios y costos no se vean mientras `AppConfig.showCosts` esté apagado |
| | `test/invitations_test.dart` | Que no se pueda invitar dos veces mientras la invitación siga abierta |
| | `test/app_navigation_test.dart` | Recorridos principales en modo demo: inicio → detalle, pestañas, invitaciones, perfiles, recetario y filtros, tema, barra de 5 pestañas |
| | `test/auth_flow_test.dart` | Login, registro, cierre de sesión y redirecciones |
| | `test/api_client_test.dart` | Contrato JSON y manejo de errores del `ApiClient` |
| | `test/recipe_calculators_test.dart` | Porciones, costos y comparación de versiones |
| | `test/recipe_permissions_test.dart` | Reglas de autor / versiones |
| `cd backend && php artisan test` | `backend/tests/Feature/AuthTest.php`, `RecipesTest.php`, `SocialTest.php`, `SyncTest.php` | Reglas de negocio de la API y forma de `/sync` |
| `dart run tool/api_smoke_test.dart` | `tool/api_smoke_test.dart` | Punta a punta contra la API corriendo (crea datos reales) |
| `flutter test integration_test` | `integration_test/live_api_test.dart` | La app contra la API real |

---

## 12. Checklist antes de hacer commit

- [ ] `flutter analyze` sin errores.
- [ ] `flutter test` en verde.
- [ ] `cd backend && php artisan test` en verde.
- [ ] Si tocaste un JSON, enum o ruta de notificación: cambiaste **los dos lados** (§2).
- [ ] Si agregaste un método a un repositorio: está en `Api*Repository` **y** en `DemoBackend`.
- [ ] Si cambiaste la base: migración **nueva** (no editar las viejas) y `php artisan migrate` funciona.
- [ ] Si cambiaste datos demo: regeneraste `demo.json` con `tool/export_mock_data.dart`.
- [ ] Con la API corriendo (`./scripts/dev.sh`), `dart run tool/api_smoke_test.dart` pasa.
- [ ] Rama `feature/*` desde `develop`, commit con Conventional Commits (`feat:`, `fix:`, `docs:`...).
