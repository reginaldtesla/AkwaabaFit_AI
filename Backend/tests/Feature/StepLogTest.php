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
            ->assertJsonPath('entries.0.name', 'Champion User')
            ->assertJsonPath('entries.0.steps', 12000)
            ->assertJsonPath('entries.0.rank', 1)
            ->assertJsonPath('entries.0.is_me', true)
            ->assertJsonPath('me.opted_in', true)
            ->assertJsonPath('me.in_list', true)
            ->assertJsonPath('me.rank', 1)
            ->assertJsonPath('me.steps', 12000);

        $avatar = $response->json('entries.0.avatar_url');
        $this->assertIsString($avatar);
        $this->assertNotSame('', $avatar);
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
            ->assertJsonPath('entries.0.name', 'Monthly User')
            ->assertJsonPath('entries.0.steps', 12000)
            ->assertJsonPath('me.opted_in', true);
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
            ->assertJsonPath('rank', 2);
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
            ->assertJsonPath('entries.0.steps', 5000);
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
            ->assertJsonPath('entries.0.steps', 2000);
    }

    public function test_leaderboard_excludes_users_who_opted_out_of_public_board(): void
    {
        Cache::flush();

        $viewer = User::factory()->create([
            'name' => 'Viewer',
            'is_public_on_leaderboard' => true,
        ]);

        $publicUser = User::factory()->create([
            'name' => 'Public Walker',
            'is_public_on_leaderboard' => true,
        ]);

        $privateUser = User::factory()->create([
            'name' => 'Private Walker',
            'is_public_on_leaderboard' => false,
        ]);

        DailyStepLog::create([
            'user_id' => $publicUser->id,
            'step_count' => 9000,
            'log_date' => now()->toDateString(),
        ]);

        DailyStepLog::create([
            'user_id' => $privateUser->id,
            'step_count' => 15000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($viewer)->getJson('/api/leaderboard/daily');

        $response->assertStatus(200)
            ->assertJsonFragment(['name' => 'Public Walker'])
            ->assertJsonMissing(['name' => 'Private Walker']);

        $names = collect($response->json('entries'))->pluck('name')->all();
        $this->assertSame(['Public Walker'], $names);
    }

    public function test_leaderboard_me_shows_opted_out_without_rank(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Private Me',
            'is_public_on_leaderboard' => false,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 6000,
            'log_date' => now()->toDateString(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/leaderboard/daily/me');

        $response->assertStatus(200)
            ->assertJsonPath('optedIn', false)
            ->assertJsonPath('rank', null)
            ->assertJsonPath('totalUsers', null);
    }
}
