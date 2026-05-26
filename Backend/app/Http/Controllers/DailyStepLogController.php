<?php

namespace App\Http\Controllers;

use App\Http\Requests\SyncStepsRequest;
use App\Models\DailyStepLog;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class DailyStepLogController extends Controller
{
    private function cacheKeyForMonth(string $month): string
    {
        return 'monthly_leaderboard:'.$month;
    }

    private function currentMonthKey(): string
    {
        return now()->format('Y-m');
    }

    /**
     * @return array{0: string, 1: string} [startDate, endDate] inclusive Y-m-d
     */
    private function monthBounds(string $month): array
    {
        try {
            $start = Carbon::createFromFormat('Y-m', $month)->startOfMonth();
        } catch (\Throwable) {
            $start = now()->startOfMonth();
        }

        return [$start->toDateString(), $start->copy()->endOfMonth()->toDateString()];
    }

    private function resolveMonthKey(?string $month): string
    {
        if (is_string($month) && preg_match('/^\d{4}-\d{2}$/', $month)) {
            return $month;
        }

        return $this->currentMonthKey();
    }

    /**
     * Sync the user's step count for today.
     */
    public function sync(SyncStepsRequest $request): JsonResponse
    {
        $logDate = now()->toDateString();
        if ($request->filled('log_date')) {
            try {
                $logDate = Carbon::parse((string) $request->log_date)->toDateString();
            } catch (\Throwable) {
                $logDate = now()->toDateString();
            }
        }

        $log = DailyStepLog::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'log_date' => $logDate,
            ],
            [
                'step_count' => $request->step_count,
            ]
        );

        // Next viewer refreshes the cached snapshot (max once per TTL).
        Cache::forget($this->cacheKeyForMonth($this->currentMonthKey()));

        return response()->json([
            'status' => 'success',
            'message' => 'Steps synced successfully',
            'data' => $log,
        ]);
    }

    /**
     * Monthly leaderboard (steps summed for the calendar month).
     * Results are cached for 5 minutes (300 seconds).
     */
    public function dailyLeaderboard(Request $request): JsonResponse
    {
        $month = $this->resolveMonthKey($request->query('month'));
        if ($request->filled('date') && ! $request->filled('month')) {
            try {
                $month = Carbon::parse((string) $request->query('date'))->format('Y-m');
            } catch (\Throwable) {
                $month = $this->currentMonthKey();
            }
        }

        [$startDate, $endDate] = $this->monthBounds($month);

        $leaderboard = Cache::remember($this->cacheKeyForMonth($month), 300, function () use ($startDate, $endDate) {
            return User::query()
                ->join('daily_step_logs', 'users.id', '=', 'daily_step_logs.user_id')
                ->where('users.is_public_on_leaderboard', true)
                ->whereDate('daily_step_logs.log_date', '>=', $startDate)
                ->whereDate('daily_step_logs.log_date', '<=', $endDate)
                ->groupBy('users.id', 'users.name', 'users.avatar_url')
                ->orderByDesc('total_steps')
                ->orderBy('users.id')
                ->limit(50)
                ->get([
                    'users.id',
                    'users.name',
                    'users.avatar_url',
                    DB::raw("'Accra' as location"),
                    DB::raw('CAST(SUM(daily_step_logs.step_count) AS UNSIGNED) as total_steps'),
                ]);
        });

        return response()->json([
            'status' => 'success',
            'period' => 'month',
            'month' => $month,
            'data' => $leaderboard,
        ]);
    }

    /**
     * Lightweight "my rank" for the current calendar month.
     */
    public function dailyMe(): JsonResponse
    {
        $user = auth()->user();
        $month = $this->currentMonthKey();
        [$startDate, $endDate] = $this->monthBounds($month);

        $optedIn = (bool) ($user->is_public_on_leaderboard ?? false);

        $stepsThisMonth = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', '>=', $startDate)
            ->whereDate('log_date', '<=', $endDate)
            ->sum('step_count');

        if (! $optedIn) {
            return response()->json([
                'status' => 'success',
                'period' => 'month',
                'month' => $month,
                'optedIn' => false,
                'user' => [
                    'id' => (string) $user->id,
                    'name' => (string) ($user->name ?? ''),
                    'avatar_url' => $user->avatar_url,
                    'location' => 'Accra',
                ],
                'stepsThisMonth' => (int) $stepsThisMonth,
                'stepsToday' => (int) $stepsThisMonth,
                'rank' => null,
                'totalUsers' => null,
            ]);
        }

        $monthlyTotals = DailyStepLog::query()
            ->join('users', 'users.id', '=', 'daily_step_logs.user_id')
            ->whereDate('daily_step_logs.log_date', '>=', $startDate)
            ->whereDate('daily_step_logs.log_date', '<=', $endDate)
            ->where('users.is_public_on_leaderboard', true)
            ->groupBy('daily_step_logs.user_id')
            ->selectRaw('daily_step_logs.user_id, SUM(daily_step_logs.step_count) as total_steps');

        $totalUsers = (int) DB::query()
            ->fromSub($monthlyTotals, 'monthly_totals')
            ->count();

        $above = (int) DB::query()
            ->fromSub($monthlyTotals, 'monthly_totals')
            ->where('total_steps', '>', $stepsThisMonth)
            ->count();

        return response()->json([
            'status' => 'success',
            'period' => 'month',
            'month' => $month,
            'optedIn' => true,
            'user' => [
                'id' => (string) $user->id,
                'name' => (string) ($user->name ?? ''),
                'avatar_url' => $user->avatar_url,
                'location' => 'Accra',
            ],
            'stepsThisMonth' => (int) $stepsThisMonth,
            'stepsToday' => (int) $stepsThisMonth,
            'rank' => $above + 1,
            'totalUsers' => $totalUsers,
        ]);
    }
}
