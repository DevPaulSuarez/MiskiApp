<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invitations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recipe_id')->constrained()->cascadeOnDelete();
            $table->foreignId('version_id')->constrained('recipe_versions')->cascadeOnDelete();
            $table->foreignId('from_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('to_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('message', 300)->default('');
            $table->string('status', 20)->default('pending');
            $table->timestamps();
            $table->index(['to_user_id', 'status']);
            $table->index('from_user_id');
        });

        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('recipe_id')->constrained()->cascadeOnDelete();
            $table->foreignId('version_id')->constrained('recipe_versions')->cascadeOnDelete();
            // One rating per invitation.
            $table->foreignId('invitation_id')->nullable()->unique()->constrained()->nullOnDelete();
            $table->unsignedTinyInteger('stars');
            $table->unsignedTinyInteger('flavor')->default(0); // 0 = not rated
            $table->unsignedTinyInteger('presentation')->default(0);
            $table->unsignedTinyInteger('ease')->default(0);
            $table->unsignedTinyInteger('value')->default(0);
            $table->text('comment')->nullable();
            $table->timestamps();
            $table->index(['version_id', 'user_id']);
        });

        Schema::create('comments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('version_id')->constrained('recipe_versions')->cascadeOnDelete();
            $table->text('text');
            $table->timestamps();
            $table->index(['version_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('comments');
        Schema::dropIfExists('ratings');
        Schema::dropIfExists('invitations');
    }
};
