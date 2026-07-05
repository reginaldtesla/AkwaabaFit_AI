<?php

namespace App\Support;

use App\Models\DailyStepLog;
use App\Models\MealLog;
use App\Models\User;
use App\Models\WaterLog;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;

final class AdminStats
{
    /**
     * @return array<string, int>
     */
    public static function summary(): array
    {
        $now = now();

        return [
            'total_users' => User::query()->count(),
            'profiles_completed' => User::query()->where('profile_completed', true)->count(),
            'registered_7d' => User::query()
                ->where('created_at', '>=', $now->copy()->subDays(7))
                ->count(),
            'active_15m' => User::query()
                ->where('last_seen_at', '>=', $now->copy()->subMinutes(15))
                ->count(),
            'active_1h' => User::query()
                ->where('last_seen_at', '>=', $now->copy()->subHour())
                ->count(),
            'active_today' => User::query()
                ->whereDate('last_seen_at', $now->toDateString())
                ->count(),
            'steps_today' => self::distinctUsersToday(DailyStepLog::class, 'log_date'),
            'meals_today' => self::distinctUsersTodayOnTimestamp(MealLog::class, 'eaten_at'),
            'water_today' => self::distinctUsersTodayOnTimestamp(WaterLog::class, 'logged_at'),
        ];
    }

    /**
     * @return Collection<int, object{
     *     id: int,
     *     name: string,
     *     email: string,
     *     profile_completed: bool,
     *     last_seen_at: ?Carbon,
     *     created_at: Carbon,
     *     steps_today: int
     * }>
     */
    public static function recentUsers(int $limit = 50): Collection
    {
        $today = now()->toDateString();

        return User::query()
            ->select(['id', 'name', 'email', 'profile_completed', 'last_seen_at', 'created_at'])
            ->orderByRaw('last_seen_at IS NULL')
            ->orderByDesc('last_seen_at')
            ->limit($limit)
            ->get()
            ->map(function (User $user) use ($today) {
                $stepsToday = 0;
                if (Schema::hasTable('daily_step_logs')) {
                    $stepsToday = (int) DailyStepLog::query()
                        ->where('user_id', $user->id)
                        ->whereDate('log_date', $today)
                        ->value('step_count');
                }

                return (object) [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'profile_completed' => (bool) $user->profile_completed,
                    'last_seen_at' => $user->last_seen_at,
                    'created_at' => $user->created_at,
                    'steps_today' => $stepsToday,
                ];
            });
    }

    private static function distinctUsersToday(string $modelClass, string $dateColumn): int
    {
        if (! Schema::hasTable((new $modelClass)->getTable())) {
            return 0;
        }

        return (int) $modelClass::query()
            ->whereDate($dateColumn, now()->toDateString())
            ->distinct()
            ->count('user_id');
    }

    private static function distinctUsersTodayOnTimestamp(string $modelClass, string $column): int
    {
        if (! Schema::hasTable((new $modelClass)->getTable())) {
            return 0;
        }

        return (int) $modelClass::query()
            ->whereDate($column, now()->toDateString())
            ->distinct()
            ->count('user_id');
    }
}
