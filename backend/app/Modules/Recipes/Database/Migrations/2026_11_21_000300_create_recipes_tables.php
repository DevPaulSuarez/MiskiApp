<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A dish exists once; each person contributes their way of preparing it as versions.
        Schema::create('recipes', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100)->index();
            $table->string('description', 500)->default('');
            $table->string('image_url', 500)->default(''); // absolute URL or path on the public disk
            $table->foreignId('category_id')->constrained()->restrictOnDelete();
            $table->foreignId('author_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedBigInteger('main_version_id')->nullable();
            $table->string('status', 20)->default('active')->index();
            $table->timestamps();
        });

        // Immutable snapshots: published versions are never updated. Versions form a
        // tree through parent_version_id.
        Schema::create('recipe_versions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recipe_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('number');
            $table->string('title', 100);
            $table->foreignId('parent_version_id')->nullable()->constrained('recipe_versions')->nullOnDelete();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->unsignedSmallInteger('servings');
            $table->unsignedSmallInteger('prep_minutes');
            $table->unsignedSmallInteger('cook_minutes');
            $table->string('difficulty', 10);
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->unique(['recipe_id', 'number']);
        });

        Schema::table('recipes', function (Blueprint $table) {
            $table->foreign('main_version_id')->references('id')->on('recipe_versions')->nullOnDelete();
        });

        Schema::create('version_ingredients', function (Blueprint $table) {
            $table->id();
            $table->foreignId('version_id')->constrained('recipe_versions')->cascadeOnDelete();
            $table->foreignId('ingredient_id')->constrained()->restrictOnDelete();
            $table->unsignedSmallInteger('position');
            $table->decimal('quantity', 12, 3);
            $table->string('unit', 20);
            $table->string('note', 120)->default('');
            // What the cook paid, to estimate the dish cost.
            $table->decimal('purchase_price', 10, 2)->nullable();
            $table->decimal('purchase_quantity', 12, 3)->nullable();
            $table->string('purchase_unit', 20)->nullable();
            $table->unique(['version_id', 'ingredient_id']);
        });

        Schema::create('version_steps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('version_id')->constrained('recipe_versions')->cascadeOnDelete();
            $table->unsignedSmallInteger('position');
            $table->text('text');
        });

        Schema::create('favorites', function (Blueprint $table) {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('recipe_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at')->useCurrent();
            $table->primary(['user_id', 'recipe_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('favorites');
        Schema::dropIfExists('version_steps');
        Schema::dropIfExists('version_ingredients');
        Schema::table('recipes', fn (Blueprint $t) => $t->dropForeign(['main_version_id']));
        Schema::dropIfExists('recipe_versions');
        Schema::dropIfExists('recipes');
    }
};
