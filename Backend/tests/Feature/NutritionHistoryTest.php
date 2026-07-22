<?php

namespace Tests\Feature;

use App\Models\MealLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NutritionHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_log_meal_and_fetch_history(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/nutrition/log', [
                'name' => 'Jollof Rice',
                'meal_type' => 'Lunch',
                'calories' => 650,
                'protein_g' => 18,
                'carbs_g' => 95,
                'fat_g' => 16,
                'safety_status' => 'watch',
                'insight_message' => 'Great, but watch portion size today.',
                'image_url' => 'https://example.com/img.jpg',
                'source' => 'manual',
            ])
            ->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('meal.name', 'Jollof Rice');

        $this->assertDatabaseCount('meal_logs', 1);
        $this->assertDatabaseHas('meal_logs', [
            'user_id' => $user->id,
            'name' => 'Jollof Rice',
        ]);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/nutrition/history')
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonStructure([
                'status',
                'from',
                'to',
                'days' => [
                    ['date', 'totalKcal', 'meals' => []],
                ],
            ]);
    }

    public function test_history_only_returns_authenticated_users_meals(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        MealLog::create([
            'user_id' => $userA->id,
            'eaten_at' => now(),
            'name' => 'A meal',
            'calories' => 100,
            'source' => 'manual',
        ]);

        MealLog::create([
            'user_id' => $userB->id,
            'eaten_at' => now(),
            'name' => 'B meal',
            'calories' => 200,
            'source' => 'manual',
        ]);

        $token = $userA->createToken('test')->plainTextToken;

        $res = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/nutrition/history')
            ->assertStatus(200)
            ->json();

        $allMeals = collect($res['days'])->flatMap(fn ($d) => $d['meals'])->all();
        $names = collect($allMeals)->pluck('name')->all();

        $this->assertContains('A meal', $names);
        $this->assertNotContains('B meal', $names);
    }

    public function test_history_hides_chop_bar_and_vendor_labels(): void
    {
        $user = User::factory()->create();

        MealLog::create([
            'user_id' => $user->id,
            'eaten_at' => now(),
            'name' => 'Jollof (chop bar)',
            'calories' => 580,
            'source' => 'scan',
            'insight_message' => 'Rice and stew from the chop bar, how the vendor serves it.',
        ]);

        MealLog::create([
            'user_id' => $user->id,
            'eaten_at' => now()->subHour(),
            'name' => 'Waakye chop (vendor)',
            'calories' => 720,
            'source' => 'scan',
            'insight_message' => 'Pick sides like at the vendor.',
        ]);

        Sanctum::actingAs($user);

        $res = $this->getJson('/api/nutrition/history')->assertOk()->json();
        $meals = collect($res['days'])->flatMap(fn ($d) => $d['meals']);

        foreach ($meals as $meal) {
            $blob = strtolower(($meal['name'] ?? '').' '.($meal['insightMessage'] ?? ''));
            $this->assertStringNotContainsString('chop bar', $blob);
            $this->assertStringNotContainsString('vendor', $blob);
        }

        $names = $meals->pluck('name')->all();
        $this->assertContains('Jollof', $names);
        $this->assertContains('Waakye chop', $names);
    }
}
