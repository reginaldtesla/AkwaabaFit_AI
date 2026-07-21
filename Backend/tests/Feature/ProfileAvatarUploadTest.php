<?php

namespace Tests\Feature;

use App\Models\DailyStepLog;
use App\Models\User;
use App\Support\LeaderboardCache;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProfileAvatarUploadTest extends TestCase
{
    use RefreshDatabase;

    public function test_uploading_avatar_updates_user_and_clears_leaderboard_cache(): void
    {
        Storage::fake('public');
        Cache::flush();

        $user = User::factory()->create([
            'name' => 'Photo User',
            'is_public_on_leaderboard' => true,
            'gender' => 'male',
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 3000,
            'log_date' => now()->toDateString(),
        ]);

        Cache::put(LeaderboardCache::dailyKey(now()->toDateString()), [['name' => 'stale']], 300);

        $response = $this->actingAs($user)->post('/api/profile/avatar', [
            'avatar' => UploadedFile::fake()->image('face.jpg', 200, 200),
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'success');

        $avatarUrl = $response->json('avatarUrl');
        $this->assertIsString($avatarUrl);
        $this->assertNotSame('', $avatarUrl);

        $user->refresh();
        $this->assertSame($avatarUrl, $user->avatar_url);
        $this->assertFalse(Cache::has(LeaderboardCache::dailyKey(now()->toDateString())));

        $board = $this->actingAs($user)->getJson('/api/leaderboard/daily');
        $board->assertOk()
            ->assertJsonPath('entries.0.avatar_url', $avatarUrl);
    }
}
