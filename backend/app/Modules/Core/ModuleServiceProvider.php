<?php

namespace App\Modules\Core;

use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;
use ReflectionClass;

/**
 * Base class for every module. A module is a folder under app/Modules with
 * its own models, migrations, routes and listeners. It is switched on or off
 * from config/modules.php without touching the other modules.
 *
 * Conventions inside a module folder:
 *  - routes.php            API routes, mounted under /api/v1 with the api middleware
 *  - Database/Migrations   migrations, loaded automatically
 */
abstract class ModuleServiceProvider extends ServiceProvider
{
    /** Event => listeners this module reacts to. */
    protected array $listen = [];

    public function boot(): void
    {
        $dir = dirname((new ReflectionClass(static::class))->getFileName());

        if (is_dir($dir.'/Database/Migrations')) {
            $this->loadMigrationsFrom($dir.'/Database/Migrations');
        }

        if (is_file($dir.'/routes.php') && ! $this->app->routesAreCached()) {
            Route::prefix('api/v1')->middleware('api')->group($dir.'/routes.php');
        }

        foreach ($this->listen as $event => $listeners) {
            foreach ((array) $listeners as $listener) {
                $this->app['events']->listen($event, $listener);
            }
        }
    }
}
