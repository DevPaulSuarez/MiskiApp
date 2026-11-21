<?php

use App\Modules\Catalog\CatalogServiceProvider;
use App\Modules\Identity\IdentityServiceProvider;
use App\Modules\Notifications\NotificationsServiceProvider;
use App\Modules\Recipes\RecipesServiceProvider;
use App\Modules\Social\SocialServiceProvider;
use App\Modules\Sync\SyncServiceProvider;

/*
| Enabled modules. Each entry is a module's service provider; remove a line to
| switch a module off, add one to plug a new module in (for example the future
| Shopping, Planner, Events, Menus or Pantry modules).
|
| Order matters only for migrations that reference other modules' tables:
| Identity and Catalog first.
*/

return [
    IdentityServiceProvider::class,
    CatalogServiceProvider::class,
    RecipesServiceProvider::class,
    SocialServiceProvider::class,
    NotificationsServiceProvider::class,
    SyncServiceProvider::class,
];
