<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AppVersionTest extends TestCase
{
    use RefreshDatabase;

    public function test_version_check_requires_platform(): void
    {
        $this->getJson('/api/app/version?version=1.0.0')
            ->assertStatus(422);
    }

    public function test_android_update_available_when_behind_latest(): void
    {
        config([
            'mobile_app.android.latest_version' => '2.0.0',
            'mobile_app.android.min_version' => '1.0.0',
            'mobile_app.android.store_url' => 'https://play.google.com/store/apps/details?id=com.example.app',
        ]);

        $this->getJson('/api/app/version?platform=android&version=1.0.0')
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('update_available', true)
            ->assertJsonPath('force_update', false)
            ->assertJsonPath('latest_version', '2.0.0');
    }

    public function test_no_update_when_current_matches_latest(): void
    {
        config([
            'mobile_app.android.latest_version' => '1.0.0',
            'mobile_app.android.store_url' => 'https://play.google.com/store/apps/details?id=com.example.app',
        ]);

        $this->getJson('/api/app/version?platform=android&version=1.0.0')
            ->assertOk()
            ->assertJsonPath('update_available', false);
    }

    public function test_force_update_when_below_min_version(): void
    {
        config([
            'mobile_app.ios.latest_version' => '2.0.0',
            'mobile_app.ios.min_version' => '1.5.0',
            'mobile_app.ios.store_url' => 'https://apps.apple.com/app/id123',
        ]);

        $this->getJson('/api/app/version?platform=ios&version=1.0.0')
            ->assertOk()
            ->assertJsonPath('force_update', true)
            ->assertJsonPath('update_available', true);
    }
}
