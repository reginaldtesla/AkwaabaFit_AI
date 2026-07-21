<?php

namespace Tests\Feature;

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
            ]);

        $titles = collect($response->json('tips'))->pluck('title')->all();
        $this->assertContains('Sip through the day', $titles);
    }

    public function test_health_tips_merges_gemini_refresh_with_local_bank(): void
    {
        config([
            'services.food_scan.gemini_api_key' => 'test-key',
            'services.food_scan.gemini_model' => 'gemini-2.5-flash',
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
                                    ], JSON_THROW_ON_ERROR),
                                ],
                            ],
                        ],
                    ],
                ],
            ], 200),
        ]);

        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->getJson('/api/safety/health-tips?temp_celsius=33&weather_main=Clear&refresh=1')
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('source', 'mixed')
            ->assertJsonPath('tips.0.title', 'Cool water first');

        $titles = collect($response->json('tips'))->pluck('title')->all();
        $this->assertContains('Cool water first', $titles);
        $this->assertContains('Sip through the day', $titles);
    }
}
