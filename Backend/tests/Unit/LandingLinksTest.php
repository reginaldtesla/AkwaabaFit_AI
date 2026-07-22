<?php

namespace Tests\Unit;

use App\Support\LandingLinks;
use Tests\TestCase;

class LandingLinksTest extends TestCase
{
    public function test_support_mailto_includes_recipient_subject_and_body(): void
    {
        config([
            'landing.support_email' => 'help@example.com',
            'landing.support_email_subject' => 'Hello team',
            'landing.support_email_body' => "Line one\nLine two",
        ]);

        $url = LandingLinks::supportMailto();

        $this->assertStringStartsWith('mailto:help@example.com?', $url);
        $this->assertStringContainsString('subject=Hello%20team', $url);
        $this->assertStringContainsString('body=Line%20one%0ALine%20two', $url);
    }

    public function test_apk_download_url_converts_google_drive_share_link(): void
    {
        config([
            'landing.apk_url' => 'https://drive.google.com/file/d/abc123XYZ/view?usp=drive_link',
        ]);

        $this->assertSame(
            'https://drive.google.com/uc?export=download&id=abc123XYZ',
            LandingLinks::apkDownloadUrl(),
        );
    }

    public function test_apk_download_url_passes_through_direct_urls(): void
    {
        config([
            'landing.apk_url' => 'https://api.tesnet.xyz/downloads/akwaabafit.apk',
        ]);

        $this->assertSame(
            'https://api.tesnet.xyz/downloads/akwaabafit.apk',
            LandingLinks::apkDownloadUrl(),
        );
    }

    public function test_apk_download_url_returns_null_when_unset_and_file_missing(): void
    {
        config([
            'landing.apk_url' => null,
            'landing.apk_storage_path' => storage_path('app/public/downloads/does-not-exist-'.uniqid('', true).'.apk'),
        ]);

        $this->assertNull(LandingLinks::apkDownloadUrl());
    }

    public function test_apk_download_url_uses_local_route_when_file_exists(): void
    {
        $path = storage_path('app/public/downloads/unit-test-'.uniqid('', true).'.apk');
        $dir = dirname($path);
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        file_put_contents($path, 'apk');

        config([
            'landing.apk_url' => null,
            'landing.apk_storage_path' => $path,
        ]);

        try {
            $this->assertSame(route('apk.download'), LandingLinks::apkDownloadUrl());
        } finally {
            @unlink($path);
        }
    }
}
