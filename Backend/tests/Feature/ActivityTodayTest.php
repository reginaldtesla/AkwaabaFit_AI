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
            ->assertJsonPath('stepsYesterday', null)
            ->assertJsonPath('stepGoal', 8000)
            ->assertJsonPath('hasHourlyData', true)
            ->assertJsonPath('hourlyBucketSteps.3', 900)
            ->assertJsonPath('hourlyBucketSteps.0', 0)
            ->assertJsonStructure([
                'streakDays',
                'calories',
                'distanceKm',
                'activeMinutes',
                'hourlyData',
                'hourlyBucketSteps',
                'weather' => [
                    'tempCelsius',
                    'location',
                    'main',
                    'description',
                    'airQualityAqi',
                ],
                'strideTip',
            ]);
    }

    public function test_activity_today_includes_steps_yesterday_when_logged(): void
    {
        $user = User::factory()->create();

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 1000,
            'log_date' => now()->subDay()->toDateString(),
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 500,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/activity/today');

        $response->assertStatus(200)
            ->assertJsonPath('stepsToday', 500)
            ->assertJsonPath('stepsYesterday', 1000);
    }

    public function test_hourly_bucket_steps_are_incremental_not_sum_of_cumulative_readings(): void
    {
        $user = User::factory()->create();

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 2500,
            'log_date' => now()->toDateString(),
        ]);

        // Same-day cumulative totals: hour 9 snapshot vs hour 10 snapshot (not additive).
        HourlyStepLog::create([
            'user_id' => $user->id,
            'log_date' => now()->toDateString(),
            'hour' => 9,
            'step_count' => 1000,
        ]);
        HourlyStepLog::create([
            'user_id' => $user->id,
            'log_date' => now()->toDateString(),
            'hour' => 10,
            'step_count' => 1500,
        ]);

        $response = $this->actingAs($user)->getJson('/api/activity/today');

        $response->assertStatus(200);
        // Bucket for hours 9–11: max inside (1500) − max before hour 9 (0) = 1500 (not 1000+1500).
        $response->assertJsonPath('hourlyBucketSteps.3', 1500);
    }
}
