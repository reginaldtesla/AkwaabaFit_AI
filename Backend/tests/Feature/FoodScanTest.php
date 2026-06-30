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
            'services.food_scan.hf_confidence_threshold' => 0.65,
        ]);

        Http::fake([
            'api-inference.huggingface.co/*' => Http::response([
                ['label' => 'Jollof rice Ghana', 'score' => 0.91],
            ]),
            'generativelanguage.googleapis.com/*' => Http::response(['candidates' => []]),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $jpeg = base64_decode(
            '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA8A/9k=',
            true
        );
        $file = UploadedFile::fake()->createWithContent('plate.jpg', $jpeg, 'image/jpeg');

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $file])
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('strategy', 'ghana_classifier')
            ->assertJsonPath('detections.0.class_name', 'jollof')
            ->assertJsonPath('detections.0.source', 'ghana_classifier');

        Http::assertSentCount(1);
    }

    public function test_hybrid_scan_falls_back_to_gemini_when_hf_low_confidence(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.65,
        ]);

        Http::fake([
            'api-inference.huggingface.co/*' => Http::response([
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
        $jpeg = base64_decode(
            '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA8A/9k=',
            true
        );
        $file = UploadedFile::fake()->createWithContent('plate.jpg', $jpeg, 'image/jpeg');

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $file])
            ->assertStatus(200)
            ->assertJsonPath('strategy', 'gemini_flash_fallback')
            ->assertJsonPath('detections.0.class_name', 'banku')
            ->assertJsonPath('detections.0.source', 'gemini_flash');
    }

    public function test_hybrid_scan_rejects_weak_detections_as_not_food(): void
    {
        config([
            'services.food_scan.huggingface_token' => 'hf-test',
            'services.food_scan.gemini_api_key' => 'gemini-test',
            'services.food_scan.hf_confidence_threshold' => 0.65,
            'services.food_scan.min_detection_confidence' => 0.30,
        ]);

        Http::fake([
            'api-inference.huggingface.co/*' => Http::response([
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
        $jpeg = base64_decode(
            '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA8A/9k=',
            true
        );
        $file = UploadedFile::fake()->createWithContent('not-food.jpg', $jpeg, 'image/jpeg');

        $this->withHeader('Authorization', "Bearer {$token}")
            ->post('/api/nutrition/scan', ['image' => $file])
            ->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('strategy', 'none')
            ->assertJsonPath('detections', []);
    }
}
