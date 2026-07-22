<?php

use App\Models\AdminAnnouncement;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

test('authenticated user can list announcements after an id', function () {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $first = AdminAnnouncement::create([
        'title' => 'First',
        'body' => 'Hello first message here',
        'sent_at' => now()->subHour(),
    ]);
    $second = AdminAnnouncement::create([
        'title' => 'Second',
        'body' => 'Hello second message here',
        'sent_at' => now(),
    ]);

    $this->getJson('/api/announcements?after_id='.$first->id)
        ->assertSuccessful()
        ->assertJsonPath('status', 'success')
        ->assertJsonCount(1, 'announcements')
        ->assertJsonPath('announcements.0.id', $second->id)
        ->assertJsonPath('announcements.0.title', 'Second');
});

test('user can register a device token', function () {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $token = str_repeat('fcm_token_value_', 3);

    $this->postJson('/api/device-tokens', [
        'token' => $token,
        'platform' => 'android',
    ])
        ->assertSuccessful()
        ->assertJsonPath('status', 'success');

    $this->assertDatabaseHas('device_tokens', [
        'user_id' => $user->id,
        'token' => $token,
        'platform' => 'android',
    ]);
});

test('announcement endpoints require auth', function () {
    $this->getJson('/api/announcements')->assertUnauthorized();
    $this->postJson('/api/device-tokens', ['token' => str_repeat('x', 40)])->assertUnauthorized();
});
