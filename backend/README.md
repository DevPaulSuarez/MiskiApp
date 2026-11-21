# Miski API

Laravel 13 + Sanctum + MySQL, organizado en módulos (`app/Modules`). La guía completa está en
[../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) y la forma de ejecutarlo en [../README.md](../README.md).

```bash
cp .env.example .env && php artisan key:generate
php artisan migrate --seed        # catálogo base + datos demo (fuera de producción)
php artisan serve --host=0.0.0.0
php artisan test
```

`database/seeders/data/demo.json` se genera desde los datos de ejemplo de la app con
`dart run tool/export_mock_data.dart > backend/database/seeders/data/demo.json`.
