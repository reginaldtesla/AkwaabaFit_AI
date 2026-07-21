<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;

final class LeaderboardCache
{
    public static function forgetCurrent(): void
    {
        // Clear a 3-day window so device timezone ≠ server timezone does not
        // leave a stale board after opt-in / step sync.
        foreach ([-1, 0, 1] as $offset) {
            $day = now()->copy()->addDays($offset)->toDateString();
            Cache::forget(self::dailyKey($day));
        }

        Cache::forget(self::monthlyKey(now()->format('Y-m')));
        Cache::forget(self::monthlyKey(now()->copy()->subMonthNoOverflow()->format('Y-m')));
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
