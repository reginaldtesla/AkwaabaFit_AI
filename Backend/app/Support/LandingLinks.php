<?php

namespace App\Support;

final class LandingLinks
{
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
