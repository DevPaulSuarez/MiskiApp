<?php

namespace Database\Factories;

use App\Modules\Identity\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<User> */
class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'handle' => fake()->unique()->numerify('cocinero####'),
            'email' => fake()->unique()->safeEmail(),
            'password' => 'password',
            'bio' => '',
            'birthday' => fake()->date(max: '-18 years'),
            'favorite_foods' => [],
        ];
    }
}
