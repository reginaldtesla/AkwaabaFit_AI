<?php

namespace App\Support;

final class UserAvatar
{
    /**
     * Absolute avatar URL for API clients (leaderboard, dashboard, profile).
     * Falls back to a gender-based placeholder when none is uploaded.
     */
    public static function url(?string $avatarUrl, ?string $gender = null): string
    {
        $avatar = trim((string) $avatarUrl);
        if ($avatar !== '') {
            if (str_starts_with($avatar, 'http://') || str_starts_with($avatar, 'https://')) {
                return $avatar;
            }

            $path = str_starts_with($avatar, '/') ? $avatar : '/'.$avatar;

            return url($path);
        }

        $g = strtolower(trim((string) $gender));

        return match ($g) {
            'male' => 'https://i.pravatar.cc/150?img=12',
            'female' => 'https://i.pravatar.cc/150?img=47',
            default => 'https://i.pravatar.cc/150?img=5',
        };
    }
}
