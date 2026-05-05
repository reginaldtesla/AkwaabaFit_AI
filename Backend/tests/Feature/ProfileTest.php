<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_update_profile_settings(): void
    {
        $user = User::factory()->create([
            'name' => 'Old Name',
            'is_public_on_leaderboard' => false,
        ]);

        $response = $this->actingAs($user)->patchJson('/api/profile', [
            'name' => 'New Name',
            'is_public_on_leaderboard' => true,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('user.name', 'New Name')
            ->assertJsonPath('user.is_public_on_leaderboard', true);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'New Name',
            'is_public_on_leaderboard' => 1,
        ]);
    }
}