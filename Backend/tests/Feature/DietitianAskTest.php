<?php

use App\Models\User;
use App\Services\DietitianAdviceService;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

test('ask endpoint returns a diet coaching answer', function () {
    config(['services.food_scan.gemini_api_key' => '']);

    $user = User::factory()->create([
        'name' => 'Kofi Mensah',
        'goal' => 'Lose weight',
    ]);

    Sanctum::actingAs($user);

    $response = $this->postJson('/api/nutrition/advice/ask', [
        'question' => 'How much water should I drink with jollof?',
    ]);

    $response->assertSuccessful()
        ->assertJsonPath('status', 'success')
        ->assertJsonStructure(['answer', 'source']);

    expect((string) $response->json('answer'))->toContain('water');
    expect($response->json('source'))->toBe('rules');
});

test('ask endpoint validates question length', function () {
    $user = User::factory()->create();

    Sanctum::actingAs($user);

    $this->postJson('/api/nutrition/advice/ask', [
        'question' => 'hi',
    ])->assertStatus(422);
});

test('dietitian service answers hydration questions with rules fallback', function () {
    config(['services.food_scan.gemini_api_key' => '']);

    $user = User::factory()->create(['name' => 'Ama']);
    $service = app(DietitianAdviceService::class);

    $result = $service->askQuestion($user, 'How can I stay hydrated in Accra heat?');

    expect($result['source'])->toBe('rules');
    expect($result['answer'])->toContain('water');
});

test('lose-weight questions beat a gain-weight profile goal including loose typo', function () {
    config(['services.food_scan.gemini_api_key' => '']);

    $user = User::factory()->create([
        'name' => 'Kofi',
        'goal' => 'Gain weight',
    ]);
    $service = app(DietitianAdviceService::class);

    $result = $service->askQuestion($user, 'what do I do to loose weight');

    expect($result['source'])->toBe('rules');
    expect(Str::lower($result['answer']))->toContain('weight loss');
    expect(Str::lower($result['answer']))->not->toContain('gain steadily');
});

test('common ghana food typos still get meal coaching', function () {
    config(['services.food_scan.gemini_api_key' => '']);

    $user = User::factory()->create(['name' => 'Ama']);
    $service = app(DietitianAdviceService::class);

    $result = $service->askQuestion($user, 'is jellof and wakye good every day');

    expect($result['source'])->toBe('rules');
    expect(Str::lower($result['answer']))->toMatch('/jollof|waakye|starch|portion/');
});

test('off-topic joking is redirected to diet help', function () {
    config(['services.food_scan.gemini_api_key' => '']);

    $user = User::factory()->create(['name' => 'Yaw']);
    $service = app(DietitianAdviceService::class);

    $result = $service->askQuestion($user, 'chale tell me the chelsea match score lol');

    expect($result['source'])->toBe('rules');
    expect(Str::lower($result['answer']))->toContain('healthy living');
    expect(Str::lower($result['answer']))->not->toContain('chelsea');
});
