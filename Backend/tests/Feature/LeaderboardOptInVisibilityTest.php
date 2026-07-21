<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\LeaderboardCache;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class LeaderboardOptInVisibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_toggling_public_leaderboard_on_makes_user_appear_after_steps_sync(): void
    {
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Fresh Opt In',
            'is_public_on_leaderboard' => false,
        ]);

        $this->actingAs($user)
            ->patchJson('/api/profile', [
                'is_public_on_leaderboard' => true,
            ])
            ->assertOk()
            ->assertJsonPath('user.is_public_on_leaderboard', true);

        $this->actingAs($user)
            ->postJson('/api/steps/sync', [
                'step_count' => 4200,
                'log_date' => now()->toDateString(),
            ])
            ->assertOk();

        $board = $this->actingAs($user)
            ->getJson('/api/leaderboard/daily?period=day&date='.now()->toDateString())
            ->assertOk()
            ->assertJsonPath('me.opted_in', true)
            ->assertJsonPath('me.steps', 4200)
            ->assertJsonPath('me.in_list', true)
            ->json('entries');

        $names = collect($board)->pluck('name')->all();
        $this->assertContains('Fresh Opt In', $names);

        $this->actingAs($user)
            ->getJson('/api/leaderboard/daily/me?period=day')
            ->assertOk()
            ->assertJsonPath('optedIn', true)
            ->assertJsonPath('stepsToday', 4200);
    }

    public function test_leaderboard_cache_is_cleared_across_nearby_dates_on_opt_in(): void
    {
        $yesterday = now()->copy()->subDay()->toDateString();
        $today = now()->toDateString();
        $tomorrow = now()->copy()->addDay()->toDateString();

        Cache::put(LeaderboardCache::dailyKey($yesterday), [['name' => 'stale']], 300);
        Cache::put(LeaderboardCache::dailyKey($today), [['name' => 'stale']], 300);
        Cache::put(LeaderboardCache::dailyKey($tomorrow), [['name' => 'stale']], 300);

        LeaderboardCache::forgetCurrent();

        $this->assertFalse(Cache::has(LeaderboardCache::dailyKey($yesterday)));
        $this->assertFalse(Cache::has(LeaderboardCache::dailyKey($today)));
        $this->assertFalse(Cache::has(LeaderboardCache::dailyKey($tomorrow)));
    }
}
