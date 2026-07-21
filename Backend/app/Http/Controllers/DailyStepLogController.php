<?php

namespace App\Http\Controllers;

use App\Http\Requests\SyncStepsRequest;
use App\Models\DailyStepLog;
use App\Models\User;
use App\Support\LeaderboardCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class DailyStepLogController extends Controller
{
    private function monthlyCacheKey(string $month): string
    {
        return LeaderboardCache::monthlyKey($month);
    }

    private function dailyCacheKey(string $date): string
    {
        return LeaderboardCache::dailyKey($date);
    }

    private function currentMonthKey(): string
    {
        return now()->format('Y-m');
    }

    private function currentDateKey(): string
    {
        return now()->toDateString();
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

    private function resolveDateKey(?string $date): string
    {
        if (is_string($date) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            return $date;
        }

        return $this->currentDateKey();
    }

    /**
     * @return 'day'|'month'
     */
    private function resolvePeriod(Request $request): string
    {
        $period = strtolower((string) $request->query('period', 'day'));

        return $period === 'month' ? 'month' : 'day';
    }

    private function forgetLeaderboardCaches(): void
    {
        LeaderboardCache::forgetCurrent();
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

        $this->forgetLeaderboardCaches();

        return response()->json([
            'status' => 'success',
            'message' => 'Steps synced successfully',
            'data' => $log,
        ]);
    }

    /**
     * Normal leaderboard: ranked opted-in users + me summary.
     * Results are cached for 5 minutes (300 seconds).
     */
    public function dailyLeaderboard(Request $request): JsonResponse
    {
        $period = $this->resolvePeriod($request);
        $viewer = $request->user();
        $viewerId = (string) $viewer->id;

        if ($period === 'month') {
            $month = $this->resolveMonthKey($request->query('month'));
            if ($request->filled('date') && ! $request->filled('month')) {
                try {
                    $month = Carbon::parse((string) $request->query('date'))->format('Y-m');
                } catch (\Throwable) {
                    $month = $this->currentMonthKey();
                }
            }

            [$startDate, $endDate] = $this->monthBounds($month);

            $rows = Cache::remember($this->monthlyCacheKey($month), 300, function () use ($startDate, $endDate) {
                return $this->leaderboardRows($startDate, $endDate, sumSteps: true);
            });

            $entries = $this->rankedEntries($rows, $viewerId);
            $me = $this->meSummary($viewer, $entries, $startDate, $endDate, sumSteps: true);

            return response()->json([
                'status' => 'success',
                'period' => 'month',
                'month' => $month,
                'entries' => $entries,
                'me' => $me,
            ]);
        }

        $date = $this->resolveDateKey($request->query('date'));

        $rows = Cache::remember($this->dailyCacheKey($date), 300, function () use ($date) {
            return $this->leaderboardRows($date, $date, sumSteps: false);
        });

        $entries = $this->rankedEntries($rows, $viewerId);
        $me = $this->meSummary($viewer, $entries, $date, $date, sumSteps: false);

        return response()->json([
            'status' => 'success',
            'period' => 'day',
            'date' => $date,
            'entries' => $entries,
            'me' => $me,
        ]);
    }

    /**
     * @return Collection<int, object>
     */
    private function leaderboardRows(string $startDate, string $endDate, bool $sumSteps): Collection
    {
        $stepsExpr = $sumSteps
            ? 'CAST(SUM(daily_step_logs.step_count) AS UNSIGNED) as total_steps'
            : 'CAST(MAX(daily_step_logs.step_count) AS UNSIGNED) as total_steps';

        return User::query()
            ->join('daily_step_logs', 'users.id', '=', 'daily_step_logs.user_id')
            ->where('users.is_public_on_leaderboard', true)
            ->whereDate('daily_step_logs.log_date', '>=', $startDate)
            ->whereDate('daily_step_logs.log_date', '<=', $endDate)
            ->groupBy('users.id', 'users.name', 'users.avatar_url')
            ->havingRaw($sumSteps ? 'SUM(daily_step_logs.step_count) > 0' : 'MAX(daily_step_logs.step_count) > 0')
            ->orderByDesc('total_steps')
            ->orderBy('users.id')
            ->limit(200)
            ->get([
                'users.id',
                'users.name',
                'users.avatar_url',
                DB::raw($stepsExpr),
            ]);
    }

    /**
     * @param  Collection<int, object>  $rows
     * @return list<array{rank: int, id: string, name: string, avatar_url: ?string, steps: int, is_me: bool}>
     */
    private function rankedEntries(Collection $rows, string $viewerId): array
    {
        $entries = [];
        $rank = 1;

        foreach ($rows as $row) {
            $id = (string) $row->id;
            $entries[] = [
                'rank' => $rank,
                'id' => $id,
                'name' => (string) ($row->name ?? ''),
                'avatar_url' => $row->avatar_url,
                'steps' => (int) ($row->total_steps ?? 0),
                'is_me' => $id === $viewerId,
            ];
            $rank++;
        }

        return $entries;
    }

    /**
     * @param  list<array{rank: int, id: string, name: string, avatar_url: ?string, steps: int, is_me: bool}>  $entries
     * @return array{opted_in: bool, rank: ?int, steps: int, in_list: bool}
     */
    private function meSummary(
        User $viewer,
        array $entries,
        string $startDate,
        string $endDate,
        bool $sumSteps,
    ): array {
        $optedIn = (bool) ($viewer->is_public_on_leaderboard ?? false);

        $stepsQuery = DailyStepLog::query()
            ->where('user_id', $viewer->id)
            ->whereDate('log_date', '>=', $startDate)
            ->whereDate('log_date', '<=', $endDate);

        $steps = $sumSteps
            ? (int) $stepsQuery->sum('step_count')
            : (int) ($stepsQuery->value('step_count') ?? 0);

        if (! $optedIn) {
            return [
                'opted_in' => false,
                'rank' => null,
                'steps' => $steps,
                'in_list' => false,
            ];
        }

        foreach ($entries as $entry) {
            if ($entry['is_me']) {
                return [
                    'opted_in' => true,
                    'rank' => $entry['rank'],
                    'steps' => $entry['steps'],
                    'in_list' => true,
                ];
            }
        }

        if ($steps <= 0) {
            return [
                'opted_in' => true,
                'rank' => null,
                'steps' => 0,
                'in_list' => false,
            ];
        }

        [$rank] = $this->rankForRange(
            userId: (int) $viewer->id,
            userSteps: $steps,
            startDate: $startDate,
            endDate: $endDate,
        );

        return [
            'opted_in' => true,
            'rank' => $rank,
            'steps' => $steps,
            'in_list' => false,
        ];
    }

    /**
     * Lightweight "my rank" for today or the current calendar month.
     * Kept for older clients; the main board embeds `me` already.
     */
    public function dailyMe(Request $request): JsonResponse
    {
        $user = $request->user();
        $period = $this->resolvePeriod($request);
        $optedIn = (bool) ($user->is_public_on_leaderboard ?? false);

        if ($period === 'month') {
            return $this->monthlyMeResponse($user, $optedIn);
        }

        return $this->dailyMeResponse($user, $optedIn);
    }

    private function monthlyMeResponse(User $user, bool $optedIn): JsonResponse
    {
        $month = $this->currentMonthKey();
        [$startDate, $endDate] = $this->monthBounds($month);

        $stepsThisMonth = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', '>=', $startDate)
            ->whereDate('log_date', '<=', $endDate)
            ->sum('step_count');

        $stepsToday = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $this->currentDateKey())
            ->value('step_count') ?? 0;

        if (! $optedIn) {
            return response()->json([
                'status' => 'success',
                'period' => 'month',
                'month' => $month,
                'optedIn' => false,
                'user' => $this->userPayload($user),
                'stepsThisMonth' => $stepsThisMonth,
                'stepsToday' => $stepsToday,
                'rank' => null,
                'totalUsers' => null,
            ]);
        }

        [$rank, $totalUsers] = $this->rankForRange(
            userId: $user->id,
            userSteps: $stepsThisMonth,
            startDate: $startDate,
            endDate: $endDate,
        );

        return response()->json([
            'status' => 'success',
            'period' => 'month',
            'month' => $month,
            'optedIn' => true,
            'user' => $this->userPayload($user),
            'stepsThisMonth' => $stepsThisMonth,
            'stepsToday' => $stepsToday,
            'rank' => $rank,
            'totalUsers' => $totalUsers,
        ]);
    }

    private function dailyMeResponse(User $user, bool $optedIn): JsonResponse
    {
        $date = $this->currentDateKey();

        $stepsToday = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $date)
            ->value('step_count') ?? 0;

        $month = $this->currentMonthKey();
        [$startDate, $endDate] = $this->monthBounds($month);
        $stepsThisMonth = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', '>=', $startDate)
            ->whereDate('log_date', '<=', $endDate)
            ->sum('step_count');

        if (! $optedIn) {
            return response()->json([
                'status' => 'success',
                'period' => 'day',
                'date' => $date,
                'optedIn' => false,
                'user' => $this->userPayload($user),
                'stepsToday' => $stepsToday,
                'stepsThisMonth' => $stepsThisMonth,
                'rank' => null,
                'totalUsers' => null,
            ]);
        }

        [$rank, $totalUsers] = $this->rankForRange(
            userId: $user->id,
            userSteps: $stepsToday,
            startDate: $date,
            endDate: $date,
        );

        return response()->json([
            'status' => 'success',
            'period' => 'day',
            'date' => $date,
            'optedIn' => true,
            'user' => $this->userPayload($user),
            'stepsToday' => $stepsToday,
            'stepsThisMonth' => $stepsThisMonth,
            'rank' => $rank,
            'totalUsers' => $totalUsers,
        ]);
    }

    /**
     * @return array{0: int, 1: int} [rank, totalUsers]
     */
    private function rankForRange(int $userId, int $userSteps, string $startDate, string $endDate): array
    {
        $totals = DailyStepLog::query()
            ->join('users', 'users.id', '=', 'daily_step_logs.user_id')
            ->whereDate('daily_step_logs.log_date', '>=', $startDate)
            ->whereDate('daily_step_logs.log_date', '<=', $endDate)
            ->where('users.is_public_on_leaderboard', true)
            ->groupBy('daily_step_logs.user_id')
            ->selectRaw(
                $startDate === $endDate
                    ? 'daily_step_logs.user_id, MAX(daily_step_logs.step_count) as total_steps'
                    : 'daily_step_logs.user_id, SUM(daily_step_logs.step_count) as total_steps'
            );

        $totalUsers = (int) DB::query()
            ->fromSub($totals, 'leaderboard_totals')
            ->where('total_steps', '>', 0)
            ->count();

        $above = (int) DB::query()
            ->fromSub($totals, 'leaderboard_totals')
            ->where('total_steps', '>', 0)
            ->where('total_steps', '>', $userSteps)
            ->count();

        return [$above + 1, $totalUsers];
    }

    /**
     * @return array<string, mixed>
     */
    private function userPayload(User $user): array
    {
        return [
            'id' => (string) $user->id,
            'name' => (string) ($user->name ?? ''),
            'avatar_url' => $user->avatar_url,
        ];
    }
}
