<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleAuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_google_auth_creates_user_and_returns_token(): void
    {
        config(['services.google.client_ids' => ['test-client-id.apps.googleusercontent.com']]);

        Http::fake([
            'oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-sub-123',
                'email' => 'new.google.user@example.com',
                'email_verified' => 'true',
                'name' => 'Google User',
                'picture' => 'https://example.com/avatar.jpg',
                'aud' => 'test-client-id.apps.googleusercontent.com',
            ], 200),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'fake-google-id-token',
            'device_name' => 'test-device',
        ])
            ->assertOk()
            ->assertJsonPath('user.email', 'new.google.user@example.com')
            ->assertJsonPath('user.google_id', 'google-sub-123')
            ->assertJsonStructure(['user', 'token']);

        $this->assertDatabaseHas('users', [
            'email' => 'new.google.user@example.com',
            'google_id' => 'google-sub-123',
        ]);
    }

    public function test_google_auth_links_existing_email_account(): void
    {
        config(['services.google.client_ids' => ['test-client-id.apps.googleusercontent.com']]);

        $user = User::factory()->create([
            'email' => 'existing@example.com',
            'username' => 'existinguser',
            'google_id' => null,
        ]);

        Http::fake([
            'oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-sub-456',
                'email' => 'existing@example.com',
                'email_verified' => true,
                'name' => 'Existing User',
                'aud' => 'test-client-id.apps.googleusercontent.com',
            ], 200),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'fake-google-id-token',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.google_id', 'google-sub-456');

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'google_id' => 'google-sub-456',
        ]);
    }

    public function test_google_auth_rejects_invalid_audience(): void
    {
        config(['services.google.client_ids' => ['allowed-client.apps.googleusercontent.com']]);

        Http::fake([
            'oauth2.googleapis.com/tokeninfo*' => Http::response([
                'sub' => 'google-sub-789',
                'email' => 'someone@example.com',
                'email_verified' => 'true',
                'name' => 'Someone',
                'aud' => 'other-client.apps.googleusercontent.com',
            ], 200),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'fake-google-id-token',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['id_token']);
    }

    public function test_google_auth_requires_configuration(): void
    {
        config(['services.google.client_ids' => []]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'fake-google-id-token',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['id_token']);
    }
}
