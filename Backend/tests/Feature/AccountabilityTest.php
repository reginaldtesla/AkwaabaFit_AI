<?php

use App\Models\AccountabilityPartner;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

test('show generates an accountability code when missing', function () {
    $user = User::factory()->create(['accountability_code' => null]);

    Sanctum::actingAs($user);

    $response = $this->getJson('/api/accountability')
        ->assertSuccessful()
        ->assertJsonPath('status', 'success')
        ->assertJsonStructure(['code', 'partner']);

    $code = $response->json('code');
    expect($code)->toBeString()->not->toBeEmpty();
    expect(strlen((string) $code))->toBe(6);

    $this->assertDatabaseHas('users', [
        'id' => $user->id,
        'accountability_code' => $code,
    ]);
});

test('users can link with a partner code', function () {
    $user = User::factory()->create(['accountability_code' => 'AAA111']);
    $partner = User::factory()->create([
        'name' => 'Partner Ama',
        'username' => 'ama_fit',
        'accountability_code' => 'BBB222',
    ]);

    Sanctum::actingAs($user);

    $this->postJson('/api/accountability/link', [
        'partner_code' => 'bbb222',
    ])
        ->assertSuccessful()
        ->assertJsonPath('status', 'success')
        ->assertJsonPath('partner.name', 'Partner Ama')
        ->assertJsonPath('partner.username', 'ama_fit');

    $this->assertDatabaseHas('accountability_partners', [
        'user_id' => $user->id,
        'partner_user_id' => $partner->id,
        'status' => 'accepted',
    ]);
    $this->assertDatabaseHas('accountability_partners', [
        'user_id' => $partner->id,
        'partner_user_id' => $user->id,
        'status' => 'accepted',
    ]);
});

test('user cannot link to their own code', function () {
    $user = User::factory()->create(['accountability_code' => 'OWN123']);

    Sanctum::actingAs($user);

    $this->postJson('/api/accountability/link', [
        'partner_code' => 'OWN123',
    ])
        ->assertStatus(422)
        ->assertJsonPath('status', 'error');
});

test('link fails for unknown partner code', function () {
    $user = User::factory()->create(['accountability_code' => 'OWN123']);

    Sanctum::actingAs($user);

    $this->postJson('/api/accountability/link', [
        'partner_code' => 'ZZZZZZ',
    ])
        ->assertNotFound()
        ->assertJsonPath('status', 'error');
});

test('user can unlink an accountability partner', function () {
    $user = User::factory()->create(['accountability_code' => 'AAA111']);
    $partner = User::factory()->create(['accountability_code' => 'BBB222']);

    AccountabilityPartner::create([
        'user_id' => $user->id,
        'partner_user_id' => $partner->id,
        'status' => 'accepted',
    ]);
    AccountabilityPartner::create([
        'user_id' => $partner->id,
        'partner_user_id' => $user->id,
        'status' => 'accepted',
    ]);

    Sanctum::actingAs($user);

    $this->deleteJson('/api/accountability/partner')
        ->assertSuccessful()
        ->assertJsonPath('status', 'success');

    expect(AccountabilityPartner::query()->count())->toBe(0);
});
