<?php

namespace Database\Seeders;

use App\Modules\Catalog\Models\Category;
use App\Modules\Catalog\Models\Ingredient;
use App\Modules\Identity\Models\User;
use App\Modules\Notifications\Models\AppNotification;
use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Social\Models\Comment;
use App\Modules\Social\Models\Invitation;
use App\Modules\Social\Models\Rating;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Demo people and dishes (Ceviche peruano de tilapia with 3 versions, etc.).
 * Every demo account signs in with <handle>@miski.test / miski1234.
 * Skipped if the demo users already exist.
 */
class DemoSeeder extends Seeder
{
    private array $users = [];

    private array $categories = [];

    private array $ingredients = [];

    private array $recipes = [];

    private array $versions = [];

    private array $invitations = [];

    public function run(): void
    {
        $data = DemoData::load();
        if (User::where('email', DemoData::email($data['users'][0]['handle']))->exists()) {
            $this->command?->info('Datos demo ya cargados.');

            return;
        }

        Model::unguarded(fn () => DB::transaction(fn () => $this->seed($data)));
    }

    private function seed(array $data): void
    {
        foreach ($data['categories'] as $c) {
            $this->categories[$c['key']] = Category::where('name', $c['name'])->value('id');
        }
        foreach ($data['ingredients'] as $i) {
            $this->ingredients[$i['key']] = Ingredient::where('name', $i['name'])->value('id');
        }

        foreach ($data['users'] as $u) {
            $user = User::create([
                'name' => $u['name'],
                'handle' => $u['handle'],
                'email' => DemoData::email($u['handle']),
                'password' => DemoData::PASSWORD,
                'bio' => $u['bio'],
                'birthday' => $u['birthday'],
                'favorite_foods' => $u['favorite_foods'],
            ]);
            $user->favoriteCategories()->sync(array_map(fn ($k) => $this->categories[$k], $u['favorite_category_keys']));
            $this->users[$u['key']] = $user->id;
        }

        foreach ($data['recipes'] as $r) {
            $this->recipes[$r['key']] = Recipe::create([
                'name' => $r['name'],
                'description' => $r['description'],
                'image_url' => $r['image_url'],
                'category_id' => $this->categories[$r['category_key']],
                'author_id' => $this->users[$r['author_key']],
                'status' => $r['status'],
                'created_at' => Carbon::parse($r['created_at']),
                'updated_at' => Carbon::parse($r['created_at']),
            ])->id;
        }

        // Parents first: versions are listed in creation order in the mock data.
        foreach ($data['versions'] as $v) {
            $version = RecipeVersion::create([
                'recipe_id' => $this->recipes[$v['recipe_key']],
                'number' => $v['number'],
                'title' => $v['title'],
                'parent_version_id' => $v['parent_key'] ? $this->versions[$v['parent_key']] : null,
                'created_by' => $this->users[$v['created_by_key']],
                'servings' => $v['servings'],
                'prep_minutes' => $v['prep_minutes'],
                'cook_minutes' => $v['cook_minutes'],
                'difficulty' => $v['difficulty'],
                'notes' => $v['notes'],
                'created_at' => Carbon::parse($v['created_at']),
            ]);
            foreach ($v['ingredients'] as $pos => $line) {
                $version->ingredients()->create([
                    'ingredient_id' => $this->ingredients[$line['ingredient_key']],
                    'position' => $pos,
                    'quantity' => $line['quantity'],
                    'unit' => $line['unit'],
                    'note' => $line['note'],
                    'purchase_price' => $line['purchase']['price'] ?? null,
                    'purchase_quantity' => $line['purchase']['quantity'] ?? null,
                    'purchase_unit' => $line['purchase']['unit'] ?? null,
                ]);
            }
            foreach ($v['steps'] as $pos => $text) {
                $version->steps()->create(['position' => $pos, 'text' => $text]);
            }
            $this->versions[$v['key']] = $version->id;
        }

        foreach ($data['recipes'] as $r) {
            Recipe::whereKey($this->recipes[$r['key']])->update(['main_version_id' => $this->versions[$r['main_version_key']]]);
        }

        foreach ($data['invitations'] as $i) {
            $this->invitations[$i['key']] = Invitation::create([
                'recipe_id' => $this->recipes[$i['recipe_key']],
                'version_id' => $this->versions[$i['version_key']],
                'from_user_id' => $this->users[$i['from_key']],
                'to_user_id' => $this->users[$i['to_key']],
                'message' => $i['message'],
                'status' => $i['status'],
                'created_at' => Carbon::parse($i['created_at']),
                'updated_at' => Carbon::parse($i['created_at']),
            ])->id;
        }

        foreach ($data['ratings'] as $r) {
            Rating::create([
                'user_id' => $this->users[$r['user_key']],
                'recipe_id' => $this->recipes[$r['recipe_key']],
                'version_id' => $this->versions[$r['version_key']],
                'invitation_id' => $r['invitation_key'] ? $this->invitations[$r['invitation_key']] : null,
                'stars' => $r['stars'],
                'flavor' => $r['flavor'],
                'presentation' => $r['presentation'],
                'ease' => $r['ease'],
                'value' => $r['value'],
                'comment' => $r['comment'],
                'created_at' => Carbon::parse($r['created_at']),
                'updated_at' => Carbon::parse($r['created_at']),
            ]);
        }

        foreach ($data['comments'] as $c) {
            Comment::create([
                'user_id' => $this->users[$c['user_key']],
                'version_id' => $this->versions[$c['version_key']],
                'text' => $c['text'],
                'created_at' => Carbon::parse($c['created_at']),
                'updated_at' => Carbon::parse($c['created_at']),
            ]);
        }

        foreach ($data['notifications'] as $n) {
            AppNotification::create([
                'user_id' => $this->users[$n['user_key']],
                'title' => $n['title'],
                'body' => $n['body'],
                'route' => $this->mapRoute($n['route']),
                'read_at' => $n['read'] ? Carbon::parse($n['created_at']) : null,
                'created_at' => Carbon::parse($n['created_at']),
            ]);
        }

        foreach ($data['favorites'] as $f) {
            DB::table('favorites')->insert([
                'user_id' => $this->users[$f['user_key']],
                'recipe_id' => $this->recipes[$f['recipe_key']],
                'created_at' => now(),
            ]);
        }
    }

    /** "/recipe/r1/versions" -> "/recipe/<real id>/versions". */
    private function mapRoute(?string $route): ?string
    {
        return $route === null ? null : preg_replace_callback(
            '#/(recipe|version)/(\w+)#',
            fn ($m) => '/'.$m[1].'/'.($m[1] === 'recipe' ? $this->recipes[$m[2]] : $this->versions[$m[2]]),
            $route,
        );
    }
}
