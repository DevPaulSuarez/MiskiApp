<?php

namespace App\Modules\Recipes\Enums;

enum RecipeStatus: string
{
    case Active = 'active';
    case Archived = 'archived';
}
