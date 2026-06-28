<?php

namespace Tests\Feature;

use App\Models\MealLog;
use App\Models\User;
use App\Services\DietitianAdviceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DietitianAdviceTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_includes_dietitian_advice(): void
    {
        $user = User::factory()->create([
            'goal' => 'Lose weight',
            'weight' => 70,
            'height' => 170,
            'age' => 28,
            'activity_level' => 'Moderately active',
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/dashboard');

        $response->assertOk()
            ->assertJsonStructure([
                'dietitianAdvice' => [
                    'headline',
                    'summary',
                    'recommendations',
                    'nextMeal',
                    'hydrationTip',
                    'portionTip',
                ],
            ]);
    }

    public function test_meal_log_gets_dietitian_insight_when_missing(): void
    {
        $user = User::factory()->create(['goal' => 'Maintain weight']);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/nutrition/log', [
            'name' => 'Jollof Rice',
            'calories' => 520,
            'protein_g' => 18,
            'carbs_g' => 72,
            'fat_g' => 16,
            'meta' => ['class_name' => 'jollof'],
        ]);

        $response->assertCreated();
        $insight = $response->json('meal.insight_message');
        $this->assertIsString($insight);
        $this->assertNotSame('', trim((string) $insight));
        $this->assertDatabaseHas('meal_logs', [
            'user_id' => $user->id,
            'name' => 'Jollof Rice',
        ]);
    }

    public function test_meal_advice_endpoint_returns_pairing_for_banku(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/nutrition/advice/meal', [
            'name' => 'Banku',
            'class_name' => 'banku',
            'calories' => 450,
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonStructure(['advice' => ['insight', 'pairing', 'portion']]);

        $this->assertStringContainsString('banku', strtolower((string) $response->json('advice.insight')));
    }

    public function test_dietitian_service_suggests_protein_when_low(): void
    {
        $user = User::factory()->create(['goal' => 'Gain weight']);
        $service = app(DietitianAdviceService::class);

        $advice = $service->dailyAdvice(
            user: $user,
            consumedKcal: 900,
            consumedProteinG: 20,
            consumedCarbsG: 100,
            consumedFatG: 25,
            targets: [
                'dailyCaloriesTarget' => 2600,
                'proteinG' => 110,
                'carbsG' => 300,
                'fatG' => 70,
            ],
            mealsLoggedToday: 1,
            mealsLogged7Days: 5,
            todayMealNames: ['Plain rice'],
        );

        $this->assertNotEmpty($advice['recommendations']);
        $this->assertNotNull($advice['nextMeal']);
    }
}
