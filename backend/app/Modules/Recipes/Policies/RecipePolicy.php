<?php

namespace App\Modules\Recipes\Policies;

use App\Modules\Identity\Models\User;
use App\Modules\Recipes\Models\Recipe;

class RecipePolicy
{
    /** Only the dish's author may change its main version, archive it or edit its card. */
    public function manage(User $user, Recipe $recipe): bool
    {
        return $recipe->isAuthoredBy($user);
    }
}
