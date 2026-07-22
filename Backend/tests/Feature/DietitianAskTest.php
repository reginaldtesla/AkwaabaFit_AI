<?php

use App\Models\User;
use App\Services\DietitianAdviceService;
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
