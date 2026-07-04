<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;

final class LeaderboardCache
{
    public static function forgetCurrent(): void
    {
        Cache::forget(self::dailyKey(now()->toDateString()));
        Cache::forget(self::monthlyKey(now()->format('Y-m')));
    }

    public static function dailyKey(string $date): string
    {
        return 'daily_leaderboard:'.$date;
    }

    public static function monthlyKey(string $month): string
    {
        return 'monthly_leaderboard:'.$month;
    }
}
