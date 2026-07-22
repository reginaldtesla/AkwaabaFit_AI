<?php

use App\Models\User;
use App\Models\WaterLog;
use Laravel\Sanctum\Sanctum;

test('hydration today returns totals and goal for authenticated user', function () {
    $user = User::factory()->create([
        'weight' => 70,
        'water_goal_ml' => 2500,
    ]);

    WaterLog::create([
        'user_id' => $user->id,
        'amount_ml' => 500,
        'logged_at' => now(),
    ]);
    WaterLog::create([
        'user_id' => $user->id,
        'amount_ml' => 250,
        'logged_at' => now(),
    ]);

    Sanctum::actingAs($user);

    $this->getJson('/api/hydration/today')
        ->assertSuccessful()
        ->assertJsonPath('status', 'success')
        ->assertJsonPath('totalMl', 750)
        ->assertJsonPath('goalMl', 2500)
        ->assertJsonPath('glasses', 3)
        ->assertJsonPath('goalGlasses', 10);
});

test('hydration log creates a water entry', function () {
    $user = User::factory()->create();

    Sanctum::actingAs($user);

    $this->postJson('/api/hydration/log', [
        'amount_ml' => 300,
    ])
        ->assertCreated()
        ->assertJsonPath('status', 'success')
        ->assertJsonPath('entry.amount_ml', 300);

    $this->assertDatabaseHas('water_logs', [
        'user_id' => $user->id,
        'amount_ml' => 300,
    ]);
});

test('hydration log rejects invalid amounts', function () {
    $user = User::factory()->create();

    Sanctum::actingAs($user);

    $this->postJson('/api/hydration/log', [
        'amount_ml' => 10,
    ])->assertStatus(422);
});

test('hydration endpoints require authentication', function () {
    $this->getJson('/api/hydration/today')->assertUnauthorized();
    $this->postJson('/api/hydration/log', ['amount_ml' => 250])->assertUnauthorized();
});
