<?php

namespace Tests\Feature;

use App\Models\MealLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SafetyHealthTipsTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_tips_keeps_local_bank_when_gemini_unavailable(): void
    {
        config(['services.food_scan.gemini_api_key' => '']);

        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->getJson('/api/safety/health-tips?temp_celsius=31&weather_main=Clear')
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('source', 'local')
            ->assertJsonStructure([
                'tips' => [
                    ['title', 'body', 'icon'],
                ],
                'mealRecommendations' => [
                    'headline',
                    'summary',
                    'recommendations',
                    'mealsReviewed',
                    'recentMeals',
                    'source',
                ],
            ]);

        $titles = collect($response->json('tips'))->pluck('title')->all();
        $this->assertContains('Sip through the day', $titles);
        $this->assertSame(0, $response->json('mealRecommendations.mealsReviewed'));
    }

    public function test_health_tips_meal_recommendations_use_nutrition_history(): void
    {
        config(['services.food_scan.gemini_api_key' => '']);

        $user = User::factory()->create();

        MealLog::factory()->create([
            'user_id' => $user->id,
            'name' => 'Banku',
            'calories' => 520,
            'protein_g' => 8,
            'carbs_g' => 70,
            'fat_g' => 12,
            'eaten_at' => now()->subDay(),
        ]);
        MealLog::factory()->create([
            'user_id' => $user->id,
            'name' => 'Waakye',
            'calories' => 480,
            'protein_g' => 12,
            'carbs_g' => 65,
            'fat_g' => 10,
            'eaten_at' => now()->subHours(5),
        ]);

        $response = $this->actingAs($user)
            ->getJson('/api/safety/health-tips')
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('mealRecommendations.mealsReviewed', 2)
            ->assertJsonPath('mealRecommendations.source', 'rules');

        $recent = $response->json('mealRecommendations.recentMeals');
        $this->assertIsArray($recent);
        $this->assertContains('Banku', $recent);
        $this->assertContains('Waakye', $recent);

        $titles = collect($response->json('tips'))->pluck('title')->all();
        $this->assertTrue(
            collect($titles)->contains(fn ($t) => str_contains(strtolower((string) $t), 'protein')
                || str_contains(strtolower((string) $t), 'colour')
                || str_contains(strtolower((string) $t), 'water')),
        );
        $this->assertStringContainsString('History', (string) $response->json('mealRecommendations.headline'));
    }

    public function test_health_tips_merges_gemini_refresh_with_local_bank(): void
    {
        config([
            'services.food_scan.gemini_api_key' => 'test-key',
            'services.food_scan.gemini_model' => 'gemini-2.0-flash',
        ]);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'tips' => [
                                            [
                                                'title' => 'Cool water first',
                                                'body' => 'As your dietitian, start with cool water before breakfast today.',
                                                'icon' => 'water',
                                            ],
                                            [
                                                'title' => 'Walk before noon',
                                                'body' => 'I want your steps early while the air is still cooler.',
                                                'icon' => 'morning',
                                            ],
                                            [
                                                'title' => 'Add leafy greens',
                                                'body' => 'Let\'s pair your starch with greens for iron-rich colour on the plate.',
                                                'icon' => 'food',
                                            ],
                                        ],
                                        'mealRecommendations' => [
                                            'headline' => 'Based on your plates',
                                            'summary' => 'I reviewed your recent History and want more protein beside your starch.',
                                            'recommendations' => [
                                                [
                                                    'category' => 'protein',
                                                    'title' => 'Add fish or beans',
                                                    'detail' => 'Pair banku with tilapia or beans at your next meal.',
                                                ],
                                                [
                                                    'category' => 'balance',
                                                    'title' => 'Keep the greens',
                                                    'detail' => 'Add okro or kontomire for colour and fibre.',
                                                ],
                                            ],
                                        ],
                                    ], JSON_THROW_ON_ERROR),
                                ],
                            ],
                        ],
                    ],
                ],
            ], 200),
        ]);

        $user = User::factory()->create();
        MealLog::factory()->create([
            'user_id' => $user->id,
            'name' => 'Banku',
            'calories' => 500,
            'protein_g' => 10,
            'eaten_at' => now(),
        ]);

        $response = $this->actingAs($user)
            ->getJson('/api/safety/health-tips?temp_celsius=33&weather_main=Clear&refresh=1')
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('source', 'mixed')
            ->assertJsonPath('tips.0.title', 'Cool water first')
            ->assertJsonPath('mealRecommendations.headline', 'Based on your plates')
            ->assertJsonPath('mealRecommendations.source', 'gemini')
            ->assertJsonPath('mealRecommendations.mealsReviewed', 1);

        $titles = collect($response->json('tips'))->pluck('title')->all();
        $this->assertContains('Cool water first', $titles);
        $this->assertContains('Sip through the day', $titles);
    }
}
