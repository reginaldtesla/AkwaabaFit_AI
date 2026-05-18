<?php

namespace Database\Factories;

use App\Models\MealLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class MealLogFactory extends Factory
{
    protected $model = MealLog::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'eaten_at' => now(),
            'meal_type' => $this->faker->randomElement(['Breakfast', 'Lunch', 'Dinner', 'Snacks']),
            'name' => $this->faker->words(3, true),
            'calories' => $this->faker->numberBetween(50, 900),
            'protein_g' => $this->faker->optional()->numberBetween(0, 80),
            'carbs_g' => $this->faker->optional()->numberBetween(0, 200),
            'fat_g' => $this->faker->optional()->numberBetween(0, 70),
            'safety_status' => $this->faker->optional()->randomElement(['safe', 'watch', 'alert']),
            'insight_message' => $this->faker->optional()->sentence(),
            'image_url' => $this->faker->optional()->imageUrl(),
            'source' => $this->faker->randomElement(['scan', 'manual']),
            'meta' => null,
        ];
    }
}
