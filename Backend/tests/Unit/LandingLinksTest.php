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

    public function test_apk_download_url_returns_null_when_unset(): void
    {
        config(['landing.apk_url' => null]);

        $this->assertNull(LandingLinks::apkDownloadUrl());
    }
}
