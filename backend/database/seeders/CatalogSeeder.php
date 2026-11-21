<?php

namespace Database\Seeders;

use App\Modules\Catalog\Models\Category;
use App\Modules\Catalog\Models\Ingredient;
use Illuminate\Database\Seeder;

/** Dish categories and a starter set of ingredients (idempotent). */
class CatalogSeeder extends Seeder
{
    public function run(): void
    {
        $data = DemoData::load();

        foreach ($data['categories'] as $i => $c) {
            Category::updateOrCreate(['name' => $c['name']], ['emoji' => $c['emoji'], 'position' => $i]);
        }

        foreach ($data['ingredients'] as $i) {
            Ingredient::firstOrCreate(['name' => $i['name']], [
                'category' => $i['category'],
                'default_unit' => $i['default_unit'],
                'description' => $i['description'],
            ]);
        }
    }
}
