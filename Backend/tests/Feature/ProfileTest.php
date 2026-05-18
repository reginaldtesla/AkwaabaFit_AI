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

    public function test_user_can_patch_daily_calories_target_without_other_fields(): void
    {
        $user = User::factory()->create([
            'daily_calories_target' => null,
        ]);

        $response = $this->actingAs($user)->patchJson('/api/profile', [
            'daily_calories_target' => 2400,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('user.daily_calories_target', 2400);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'daily_calories_target' => 2400,
        ]);
    }

    public function test_user_can_clear_daily_calories_target(): void
    {
        $user = User::factory()->create([
            'daily_calories_target' => 2400,
        ]);

        $response = $this->actingAs($user)->patchJson('/api/profile', [
            'daily_calories_target' => null,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('user.daily_calories_target', null);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'daily_calories_target' => null,
        ]);
    }
}
