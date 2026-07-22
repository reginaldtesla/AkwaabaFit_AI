<?php

namespace App\Support;

final class LandingLinks
{
    /**
     * Absolute filesystem path to the hosted APK (upload here on the server).
     */
    public static function apkStoragePath(): string
    {
        $custom = trim((string) config('landing.apk_storage_path', ''));
        if ($custom !== '') {
            return $custom;
        }

        $filename = trim((string) config('landing.apk_filename', 'akwaabafit.apk'));
        if ($filename === '') {
            $filename = 'akwaabafit.apk';
        }

        return storage_path('app/public/downloads/'.$filename);
    }

    public static function apkIsAvailable(): bool
    {
        return is_file(self::apkStoragePath());
    }

    /**
     * Direct APK download URL for the landing page.
     * Prefer LANDING_APK_URL when set (Google Drive share links are normalized);
     * otherwise serve from this app via /download/akwaabafit.apk when the file exists.
     */
    public static function apkDownloadUrl(): ?string
    {
        $raw = trim((string) config('landing.apk_url', ''));
        if ($raw !== '') {
            if (! str_contains($raw, 'drive.google.com')) {
                return $raw;
            }

            if (preg_match('~drive\.google\.com/file/d/([^/]+)~', $raw, $matches) === 1) {
                return 'https://drive.google.com/uc?export=download&id='.$matches[1];
            }

            if (preg_match('~[?&]id=([^&]+)~', $raw, $matches) === 1) {
                return 'https://drive.google.com/uc?export=download&id='.$matches[1];
            }

            return $raw;
        }

        if (! self::apkIsAvailable()) {
            return null;
        }

        return route('apk.download');
    }

    /**
     * Opens the visitor's email app with To, subject, and body pre-filled (mailto:).
     */
    public static function supportMailto(): string
    {
        $email = (string) config('landing.support_email', '');
        if ($email === '') {
            return '#';
        }

        $query = http_build_query(
            [
                'subject' => (string) config('landing.support_email_subject'),
                'body' => (string) config('landing.support_email_body'),
            ],
            '',
            '&',
            PHP_QUERY_RFC3986
        );

        return $query === '' ? "mailto:{$email}" : "mailto:{$email}?{$query}";
    }
}
