<?php

namespace App\Support;

final class LandingLinks
{
    /**
     * Direct APK download URL for the landing page (Google Drive share links are normalized).
     */
    public static function apkDownloadUrl(): ?string
    {
        $raw = trim((string) config('landing.apk_url', ''));
        if ($raw === '') {
            return null;
        }

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
