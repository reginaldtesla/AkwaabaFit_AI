<?php

namespace App\Http\Controllers;

use App\Support\LandingLinks;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class ApkDownloadController extends Controller
{
    public function __invoke(): BinaryFileResponse
    {
        $path = LandingLinks::apkStoragePath();

        if (! is_file($path)) {
            abort(404, 'AkwaabaFit APK is not available on this server yet.');
        }

        $downloadName = (string) config('landing.apk_download_name', 'AkwaabaFit.apk');

        return response()->download(
            $path,
            $downloadName,
            [
                'Content-Type' => 'application/vnd.android.package-archive',
                'Cache-Control' => 'public, max-age=3600',
            ]
        );
    }
}
