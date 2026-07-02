<?php

namespace Tests\Feature;

use App\Models\DailyStepLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class StepLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_sync_steps(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->postJson('/api/steps/sync', [
            'step_count' => 5000,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'message' => 'Steps synced successfully',
            ]);

        $this->assertDatabaseHas('daily_step_logs', [
            'user_id' => $user->id,
            'step_count' => 5000,
            'log_date' => now()->startOfDay(),
        ]);
    }

    public function test_user_can_view_daily_leaderboard_for_today(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Champion User',
            'is_public_on_leaderboard' => true,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 12000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily');

        $response->assertStatus(200)
            ->assertJsonPath('period', 'day')
            ->assertJsonFragment([
                'name' => 'Champion User',
            ]);
    }

    public function test_user_can_view_monthly_leaderboard(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Monthly User',
            'is_public_on_leaderboard' => true,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 12000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily?period=month');

        $response->assertStatus(200)
            ->assertJsonPath('period', 'month')
            ->assertJsonFragment([
                'name' => 'Monthly User',
            ]);
    }

    public function test_user_can_fetch_their_daily_rank_for_today(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Me',
            'is_public_on_leaderboard' => true,
        ]);

        $other = User::factory()->create([
            'name' => 'Other',
            'is_public_on_leaderboard' => true,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 5000,
            'log_date' => now()->toDateString(),
        ]);

        DailyStepLog::create([
            'user_id' => $other->id,
            'step_count' => 8000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily/me');

        $response->assertStatus(200)
            ->assertJsonPath('period', 'day')
            ->assertJsonPath('optedIn', true)
            ->assertJsonPath('stepsToday', 5000)
            ->assertJsonPath('rank', 2)
            ->assertJsonPath('user.location', 'Accra');
    }

    public function test_user_can_fetch_their_monthly_rank(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Me',
            'is_public_on_leaderboard' => true,
        ]);

        $other = User::factory()->create([
            'name' => 'Other',
            'is_public_on_leaderboard' => true,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 5000,
            'log_date' => now()->toDateString(),
        ]);

        DailyStepLog::create([
            'user_id' => $other->id,
            'step_count' => 8000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily/me?period=month');

        $response->assertStatus(200)
            ->assertJsonPath('period', 'month')
            ->assertJsonPath('optedIn', true)
            ->assertJsonPath('stepsThisMonth', 5000)
            ->assertJsonPath('rank', 2);
    }

    public function test_leaderboard_sums_steps_across_days_in_same_month(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Monthly Walker',
            'is_public_on_leaderboard' => true,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 3000,
            'log_date' => now()->startOfMonth()->toDateString(),
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 2000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily?period=month');

        $response->assertStatus(200)
            ->assertJsonPath('data.0.total_steps', 5000);
    }

    public function test_daily_leaderboard_uses_today_only_not_month_total(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Today Walker',
            'is_public_on_leaderboard' => true,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 9000,
            'log_date' => now()->startOfMonth()->toDateString(),
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 2000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily');

        $response->assertStatus(200)
            ->assertJsonPath('period', 'day')
            ->assertJsonPath('data.0.total_steps', 2000);
    }
}
