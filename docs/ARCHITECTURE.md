# Arquitectura de Miski

Miski está hecho para crecer por **módulos**: cada dominio (recetas, social, notificaciones...) vive en su
carpeta, con sus datos, reglas y rutas, en la app y en el backend. Los módulos futuros del plan (compras,
planificador semanal, eventos, menús, despensa) se agregan como módulos nuevos sin tocar los existentes.

## Backend (Laravel 13)

```
backend/app/Modules/
  Core/            ModuleServiceProvider: carga routes.php y Database/Migrations de cada módulo
  Identity/        usuarios, registro/login (Sanctum), perfil
  Catalog/         categorías, ingredientes, unidades de medida
  Recipes/         platos, versiones (inmutables), favoritos, fotos
  Social/          invitaciones, calificaciones, comentarios
  Notifications/   avisos dentro de la app (escucha eventos de los otros módulos)
  Sync/            foto inicial de datos para la app (GET /sync)
backend/config/modules.php   lista de módulos activos
```

Cada módulo sigue la misma forma: `Models/`, `Http/Controllers`, `Http/Requests`, `Http/Resources`,
`Database/Migrations`, `Events/`, `routes.php` y un `*ServiceProvider`.

**Comunicación entre módulos por eventos.** Recetas y Social disparan eventos (`VersionPublished`,
`InvitationSent`, `InvitationAnswered`, `RatingCreated`, `CommentPosted`); Notificaciones los escucha y crea los
avisos. Recetas y Social no saben que Notificaciones existe: si se desactiva, simplemente no hay avisos. Las
notificaciones push (FCM) se pueden sumar después como otro listener.

### Agregar un módulo (ej. Compras)

1. Crear `app/Modules/Shopping/ShoppingServiceProvider.php` que extienda `ModuleServiceProvider`.
2. Poner sus migraciones en `Shopping/Database/Migrations` y sus rutas en `Shopping/routes.php`
   (se montan solas bajo `/api/v1` con el middleware `api`).
3. Registrarlo en `config/modules.php`.
4. Si necesita reaccionar a algo de otro módulo, escuchar su evento en `$listen`.

### Reglas de negocio que impone el servidor

- Un plato existe una vez; su primera versión es la principal. Cualquiera puede publicar su versión de un plato
  (queda con su nombre y su número correlativo, bloqueando la fila para que no se repitan números).
- Las versiones publicadas **no se modifican** (el modelo lo impide); editar crea una versión nueva con
  `parent_version_id` (árbol de versiones).
- Solo el autor del plato cambia la versión principal, lo archiva o edita su ficha (`RecipePolicy`).
- Al publicar una versión del plato de otra persona, el autor recibe un aviso con **solo** los ingredientes
  agregados y quitados.
- Invitaciones: solo el invitado responde y solo una vez; para calificar debe haber aceptado; una calificación
  por invitación (al calificar, la invitación pasa a "completada" y el comentario aparece en la versión). Sin
  invitación: no puedes calificar tu propia versión y solo una vez por versión.
- La unidad de compra debe ser compatible con la unidad usada en la receta (masa, volumen o unidades).
- Ingredientes sin duplicados: crear uno con un nombre existente (sin importar mayúsculas) devuelve el existente.
- Los platos archivados se ocultan a los demás, salvo que una invitación tuya apunte a ellos.

### API (`/api/v1`, JSON, token `Authorization: Bearer ...`)

| Método | Ruta | Uso |
|---|---|---|
| POST | `auth/register`, `auth/login` | crea cuenta / inicia sesión → `{token, user}` (10 intentos/min) |
| GET · POST | `auth/me` · `auth/logout` | usuario actual · revoca el token |
| PATCH | `me` | nombre, usuario, bio, cumpleaños, comidas y categorías favoritas |
| GET | `users`, `users/{id}` | perfiles públicos (sin correo) |
| GET | `sync` | todo lo que la app necesita al iniciar |
| GET | `categories`, `ingredients` · POST `ingredients` | catálogo · buscar o crear ingrediente |
| GET · POST | `recipes` | platos visibles · crear plato con su V1 |
| GET · PATCH | `recipes/{id}` | plato con sus versiones · cambios del autor |
| POST | `recipes/{id}/versions` | nueva versión desde `parent_version_id` |
| GET | `versions/{id}` | una versión |
| GET · PUT · DELETE | `favorites`, `favorites/{recipe}` | favoritos |
| POST | `uploads/images` | foto del plato (jpg/png/webp, máx. 6 MB) → `{path, url}` |
| GET · POST · PATCH | `invitations`, `invitations/{id}` | listar · invitar · aceptar/rechazar |
| POST | `ratings` | calificar (con o sin invitación) |
| GET · POST | `versions/{id}/comments` | comentarios |
| GET · POST | `notifications`, `notifications/{id}/read`, `notifications/read-all` | avisos |

Los ids viajan como texto. Las fechas son ISO 8601 en UTC y los cumpleaños `AAAA-MM-DD`. Los errores
devuelven `{message, errors}` en español (422 para validación).

### Modelo de datos

```
users ─┬─< recipes (author_id) ──< recipe_versions ─┬─< version_ingredients >── ingredients
       │        │  main_version_id ─────────┘       ├─< version_steps
       │        └─< favorites >── users            ├─ parent_version_id (árbol)
       ├─< invitations (from/to) ── version        ├─< ratings (invitation_id único)
       ├─< app_notifications                       └─< comments
       └─< user_favorite_categories >── categories ──< recipes
```

## App (Flutter)

```
lib/
  app/              tema, router (redirección según sesión), barra inferior, ActivitySync
  core/
    config/         AppConfig (MISKI_API_URL por --dart-define; sin ella, modo demo)
    network/        ApiClient (token, JSON, errores → ApiException en español)
    session/        SessionController (login, registro, logout, refresh) y AppSnapshot
    storage/        token en Keychain / almacenamiento cifrado
    demo/           DemoBackend: backend en memoria para pruebas y modo demo
  features/<módulo>/
    domain/         entidades, servicios puros (costos, porciones, comparar versiones) y contratos (repositorios)
    data/           implementación HTTP de los contratos + mapeo JSON + provider que elige HTTP o demo
    presentation/   pantallas, widgets y providers de estado
```

**Flujo de datos.** Al iniciar sesión, la app descarga `GET /sync` y cada provider de estado (`recipesProvider`,
`versionsProvider`, `invitationsProvider`...) arranca desde esa foto. Las pantallas leen esos providers de forma
síncrona. Al guardar algo, el provider llama al repositorio, espera la respuesta del servidor y actualiza su
estado con lo que devolvió (favoritos son optimistas). `ActivitySync` recarga al deslizar hacia abajo, al volver
la app al frente y cuando el sondeo de notificaciones (cada 45 s) trae novedades.

**Cambiar de fuente de datos** (paginación, caché offline, otro backend) es cambiar la implementación del
contrato en `data/`; las pantallas no cambian. Para crecer más allá de la foto completa de `/sync`, cada módulo ya
tiene sus endpoints propios.

**Agregar un módulo** en la app: crear `features/<módulo>/{domain,data,presentation}`, registrar sus rutas en
`app/router/app_router.dart` y, si lo necesita, su parte de `AppSnapshot`.
