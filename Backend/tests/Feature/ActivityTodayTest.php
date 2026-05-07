<?php

namespace Tests\Feature;

use App\Models\DailyStepLog;
use App\Models\HourlyStepLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ActivityTodayTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_fetch_activity_today(): void
    {
        $user = User::factory()->create([
            'activity_level' => 'Lightly active',
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 6000,
            'log_date' => now()->toDateString(),
        ]);

        HourlyStepLog::create([
            'user_id' => $user->id,
            'log_date' => now()->toDateString(),
            'hour' => 9,
            'step_count' => 900,
        ]);

        $response = $this->actingAs($user)->getJson('/api/activity/today');

        $response->assertStatus(200)
            ->assertJsonPath('stepsToday', 6000)
            ->assertJsonPath('stepGoal', 8000)
            ->assertJsonPath('hasHourlyData', true)
            ->assertJsonStructure([
                'streakDays',
                'calories',
                'distanceKm',
                'activeMinutes',
                'hourlyData',
            ]);
    }
}

