<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class FoodScanTest extends TestCase
{
    use RefreshDatabase;

    public function test_hybrid_scan_uses_ghana_classifier_when_confident(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'Jollof rice Ghana', 'score' => 0.91],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response(['candidates' => []]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('plate.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('strategy', 'ghana_classifier')
            ->assertJsonPath('detections.0.class_name', 'jollof')
            ->assertJsonPath('detections.0.source', 'ghana_classifier');

        Http::assertSentCount(1);
    }

    public function test_hybrid_scan_accepts_mid_confidence_ghana_classifier(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'Okro stew Ghana', 'score' => 0.58],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response(['candidates' => []]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('okro.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('strategy', 'ghana_classifier')
            ->assertJsonPath('detections.0.class_name', 'okro');

        Http::assertSentCount(1);
    }

    public function test_hybrid_scan_falls_back_to_gemini_when_hf_low_confidence(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'Banku Ghana', 'score' => 0.42],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'foods' => [
                                            ['name' => 'banku', 'confidence' => 0.88],
                                        ],
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('plate.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('strategy', 'gemini_flash_fallback')
            ->assertJsonPath('detections.0.class_name', 'banku')
            ->assertJsonPath('detections.0.source', 'hybrid_agreement');
    }

    public function test_gemini_fallback_maps_multi_item_ghana_plate(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'unknown dish', 'score' => 0.20],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'foods' => [
                                            ['name' => 'banku', 'confidence' => 0.92],
                                            ['name' => 'okro', 'confidence' => 0.81],
                                            ['name' => 'tilapia', 'confidence' => 0.77],
                                        ],
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('mixed.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('strategy', 'gemini_flash_fallback');

        $classes = collect($response->json('detections'))->pluck('class_name')->all();
        $this->assertSame(['banku', 'okro', 'tilapia'], $classes);
    }

    public function test_hf_alias_maps_plantain_typo_and_red_red(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'Roasted plaintain Ghana', 'score' => 0.84],
                ['label' => 'Red red Ghana', 'score' => 0.71],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response(['candidates' => []]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('plantain.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('strategy', 'ghana_classifier');

        $classes = collect($response->json('detections'))->pluck('class_name')->all();
        $this->assertContains('plantain', $classes);
        $this->assertContains('beans', $classes);
    }

    public function test_gemini_maps_descriptive_plantain_kontomire_labels(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'unknown plate', 'score' => 0.18],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'foods' => [
                                            ['name' => 'boiled ripe plantain', 'confidence' => 0.9],
                                            ['name' => 'palava sauce with fish', 'confidence' => 0.84],
                                        ],
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('ampesi.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('strategy', 'gemini_flash_fallback');

        $classes = collect($response->json('detections'))->pluck('class_name')->all();
        $this->assertContains('plantain', $classes);
        $this->assertContains('kontomire', $classes);
    }

    public function test_hybrid_scan_rejects_weak_detections_as_not_food(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.55,
            'services.food_scan.min_detection_confidence' => 0.30,
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response([
                ['label' => 'Banku Ghana', 'score' => 0.22],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                ['text' => json_encode(['foods' => []])],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('not-food.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('strategy', 'none')
            ->assertJsonPath('not_food', true)
            ->assertJsonPath('detections', []);
    }

    public function test_hybrid_scan_returns_service_error_when_ai_providers_fail(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
        ]);

        Http::fake([
            'router.huggingface.co/*' => Http::response('model loading', 503),
            'generativelanguage.googleapis.com/*' => Http::response('quota exceeded', 429),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        // Providers failing soft-returns empty rows → not_food, not a hard 503.
        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $this->sampleJpeg('desk.jpg')])
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('not_food', true)
            ->assertJsonPath('detections', []);
    }

    private function sampleJpeg(string $name): UploadedFile
    {
        $jpeg = base64_decode(
            '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA8A/9k=',
            true
        );

        return UploadedFile::fake()->createWithContent($name, $jpeg, 'image/jpeg');
    }
}
