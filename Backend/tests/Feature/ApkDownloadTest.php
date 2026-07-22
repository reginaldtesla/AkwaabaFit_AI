<?php

namespace Tests\Feature;

use App\Support\LandingLinks;
use Tests\TestCase;

class ApkDownloadTest extends TestCase
{
    public function test_apk_download_returns_404_when_file_is_missing(): void
    {
        $missing = storage_path('app/public/downloads/missing-test-'.uniqid('', true).'.apk');
        config([
            'landing.apk_storage_path' => $missing,
            'landing.apk_url' => null,
        ]);

        $this->get(route('apk.download'))->assertNotFound();
    }

    public function test_apk_download_forces_a_file_download_when_present(): void
    {
        $dir = storage_path('app/public/downloads');
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $path = $dir.'/test-akwaabafit-'.uniqid('', true).'.apk';
        file_put_contents($path, 'PK-fake-apk-bytes');

        config([
            'landing.apk_storage_path' => $path,
            'landing.apk_download_name' => 'AkwaabaFit.apk',
            'landing.apk_url' => null,
        ]);

        try {
            $response = $this->get(route('apk.download'));
            $response->assertOk();
            $response->assertHeader('content-disposition');
            $this->assertStringContainsString(
                'AkwaabaFit.apk',
                (string) $response->headers->get('content-disposition'),
            );
        } finally {
            @unlink($path);
        }
    }

    public function test_landing_links_to_local_apk_route_when_file_exists_and_env_url_is_empty(): void
    {
        $dir = storage_path('app/public/downloads');
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $path = $dir.'/test-link-'.uniqid('', true).'.apk';
        file_put_contents($path, 'apk');

        config([
            'landing.apk_storage_path' => $path,
            'landing.apk_url' => null,
        ]);

        try {
            $this->assertTrue(LandingLinks::apkIsAvailable());
            $this->assertSame(route('apk.download'), LandingLinks::apkDownloadUrl());
        } finally {
            @unlink($path);
        }
    }
}
