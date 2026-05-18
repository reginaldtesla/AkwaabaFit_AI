<?php

namespace Tests\Feature;

use App\Models\FoodNutritionItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FoodNutritionLookupTest extends TestCase
{
    use RefreshDatabase;

    public function test_food_lookup_returns_nutrition_for_class(): void
    {
        FoodNutritionItem::create([
            'class_name' => 'jollof',
            'display_name' => 'Jollof rice',
            'calories' => 420,
            'protein_g' => 14,
            'carbs_g' => 58,
            'fat_g' => 15,
            'iron_mg' => 2.2,
            'folate_mcg' => 45,
            'safety_status' => 'safe',
            'insight_message' => 'Tomato-based rice.',
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/nutrition/food?class_name=jollof')
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('food.displayName', 'Jollof rice')
            ->assertJsonPath('food.calories', 420);
    }

    public function test_foods_returns_catalog(): void
    {
        FoodNutritionItem::create([
            'class_name' => 'waakye',
            'display_name' => 'Waakye',
            'calories' => 450,
            'protein_g' => 18,
            'carbs_g' => 62,
            'fat_g' => 12,
            'iron_mg' => 4.0,
            'folate_mcg' => 52,
            'safety_status' => 'safe',
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $res = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/nutrition/foods')
            ->assertStatus(200)
            ->json();

        $this->assertSame('success', $res['status']);
        $this->assertCount(1, $res['foods']);
        $this->assertSame('waakye', $res['foods'][0]['className']);
    }
}
