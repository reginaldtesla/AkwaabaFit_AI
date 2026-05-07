<?php

namespace Tests\Feature;

use App\Models\DailyStepLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_fetch_dashboard_data(): void
    {
        $user = User::factory()->create([
            'name' => 'Kwame',
            'activity_level' => 'Moderately active',
            'weight' => 70,
            'gender' => 'Male',
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 5000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('userName', 'Kwame')
            ->assertJsonPath('avatarUrl', 'https://i.pravatar.cc/150?img=12')
            ->assertJsonPath('currentSteps', 5000)
            ->assertJsonPath('stepGoal', 10000)
            ->assertJsonStructure([
                'location',
                'alertTitle',
                'alertMessage',
                'calories',
                'activeMinutes',
            ]);
    }
}

