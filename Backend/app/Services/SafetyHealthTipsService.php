<?php

namespace App\Services;

use App\Models\MealLog;
use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Safety Hub tips: local dietitian tip bank + Gemini refresh, personalized from meal history.
 */
class SafetyHealthTipsService
{
    /**
     * @return array{
     *   tips: list<array{title: string, body: string, icon: string}>,
     *   source: string,
     *   mealRecommendations: array{
     *     headline: string,
     *     summary: string,
     *     recommendations: list<array{category: string, title: string, detail: string}>,
     *     mealsReviewed: int,
     *     recentMeals: list<string>,
     *     source: string
     *   }
     * }
     */
    public function tips(
        ?float $tempCelsius = null,
        ?string $weatherMain = null,
        ?int $airQualityAqi = null,
        bool $forceRefresh = false,
        ?User $user = null,
    ): array {
        $local = $this->localTips();
        $mealContext = $this->mealHistoryContext($user);
        $mealAdvice = $this->ruleBasedMealRecommendations($mealContext);

        $cacheKey = 'safety_health_tips:v3:'.md5(json_encode([
            $user?->id ?? 0,
            round($tempCelsius ?? 0),
            strtolower(trim((string) $weatherMain)),
            $airQualityAqi ?? 0,
            $mealContext['fingerprint'],
            now()->format('Y-m-d-H'),
        ], JSON_THROW_ON_ERROR));

        if (! $forceRefresh && Cache::has($cacheKey)) {
            /** @var array{tips: list<array{title: string, body: string, icon: string}>, source: string, mealRecommendations: array<string, mixed>} $cached */
            $cached = Cache::get($cacheKey);

            return $cached;
        }

        $gemini = $this->tryGeminiTips(
            $tempCelsius,
            $weatherMain,
            $airQualityAqi,
            $local,
            $mealContext,
        );

        if ($gemini === null) {
            $payload = [
                'tips' => $this->mergeTips($this->mealAwareLocalTips($mealContext), $local),
                'source' => 'local',
                'mealRecommendations' => $mealAdvice,
            ];
            Cache::put($cacheKey, $payload, now()->addMinutes(20));

            return $payload;
        }

        $tips = $this->mergeTips($gemini['tips'], $local);
        $mealRecommendations = $gemini['mealRecommendations'] ?? $mealAdvice;
        if (($mealRecommendations['recommendations'] ?? []) === []) {
            $mealRecommendations = $mealAdvice;
        } else {
            $mealRecommendations['mealsReviewed'] = $mealContext['meals_count'];
            $mealRecommendations['recentMeals'] = $mealContext['recent_meal_names'];
            $mealRecommendations['source'] = 'gemini';
        }

        $payload = [
            'tips' => $tips,
            'source' => 'mixed',
            'mealRecommendations' => $mealRecommendations,
        ];
        Cache::put($cacheKey, $payload, now()->addMinutes(20));

        return $payload;
    }

    /**
     * @param  list<array{title: string, body: string, icon: string}>  $fresh
     * @param  list<array{title: string, body: string, icon: string}>  $local
     * @return list<array{title: string, body: string, icon: string}>
     */
    private function mergeTips(array $fresh, array $local): array
    {
        $seen = [];
        $merged = [];

        foreach ([...$fresh, ...$local] as $tip) {
            $key = strtolower(trim($tip['title']));
            if ($key === '' || isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $merged[] = $tip;
            if (count($merged) >= 12) {
                break;
            }
        }

        return $merged;
    }

    /**
     * @param  array<string, mixed>  $mealContext
     * @return list<array{title: string, body: string, icon: string}>
     */
    private function mealAwareLocalTips(array $mealContext): array
    {
        $tips = [];
        $count = (int) ($mealContext['meals_count'] ?? 0);
        $avgProtein = (float) ($mealContext['avg_protein_g'] ?? 0);
        $names = array_map('strtolower', $mealContext['recent_meal_names'] ?? []);

        if ($count === 0) {
            $tips[] = [
                'title' => 'Log your next plate',
                'body' => 'As your dietitian, I coach best from your History. Scan or log a meal so I can tailor today\'s advice to you.',
                'icon' => 'food',
            ];

            return $tips;
        }

        if ($avgProtein < 18) {
            $tips[] = [
                'title' => 'Boost your protein',
                'body' => 'Looking at your recent meals, protein looks light. Add beans, eggs, fish, or lean meat to your next plate.',
                'icon' => 'protein',
            ];
        }

        $starchHeavy = collect($names)->filter(function (string $n) {
            return str_contains($n, 'banku')
                || str_contains($n, 'fufu')
                || str_contains($n, 'kenkey')
                || str_contains($n, 'rice')
                || str_contains($n, 'waakye')
                || str_contains($n, 'yam')
                || str_contains($n, 'plantain');
        })->count();

        if ($starchHeavy >= 2) {
            $tips[] = [
                'title' => 'Add colour next',
                'body' => 'Your History shows filling starches—good fuel. I\'d still like kontomire, okro, or garden eggs beside them.',
                'icon' => 'food',
            ];
        }

        $tips[] = [
            'title' => 'Stay steady on water',
            'body' => 'With meals already logged, keep sipping water between plates so energy and digestion stay even.',
            'icon' => 'water',
        ];

        return $tips;
    }

    /**
     * @param  list<array{title: string, body: string, icon: string}>  $localTips
     * @param  array<string, mixed>  $mealContext
     * @return array{tips: list<array{title: string, body: string, icon: string}>, mealRecommendations?: array<string, mixed>}|null
     */
    private function tryGeminiTips(
        ?float $tempCelsius,
        ?string $weatherMain,
        ?int $airQualityAqi,
        array $localTips,
        array $mealContext,
    ): ?array {
        $apiKey = trim((string) config('services.food_scan.gemini_api_key', ''));
        if ($apiKey === '') {
            return null;
        }

        $existingTitles = array_values(array_map(
            fn (array $t) => $t['title'],
            $localTips,
        ));

        $context = [
            'temp_celsius' => $tempCelsius,
            'weather_main' => $weatherMain,
            'air_quality_aqi' => $airQualityAqi,
            'existing_local_tip_titles' => $existingTitles,
            'meal_history' => [
                'days' => $mealContext['days'],
                'meals_count' => $mealContext['meals_count'],
                'total_kcal' => $mealContext['total_kcal'],
                'avg_kcal_per_meal' => $mealContext['avg_kcal'],
                'avg_protein_g' => $mealContext['avg_protein_g'],
                'avg_carbs_g' => $mealContext['avg_carbs_g'],
                'avg_fat_g' => $mealContext['avg_fat_g'],
                'recent_meals' => $mealContext['recent_meal_names'],
            ],
            'voice' => 'personal dietitian coach in AkwaabaFit',
        ];

        $prompt = 'You are the warm, professional registered dietitian inside AkwaabaFit, coaching one client. '
            .'Write short Safety Hub coaching tips in caring 2nd person ("you"), practical, not preachy, no medical diagnosis. '
            .'Use meal_history from Nutrition History when present—reference real meal patterns (protein, starch, variety) without inventing meals they did not log. '
            .'If meals_count is 0, gently nudge them to log meals. Tie tips to weather when useful. '
            .'Do not name any country or nationality in titles or bodies. '
            .'Do NOT repeat these existing tip titles: '.json_encode($existingTitles, JSON_UNESCAPED_UNICODE).'. '
            .'JSON only: {'
            .'"tips":[{"title":"max 40 chars","body":"max 160 chars, dietitian voice","icon":"water|shade|food|walk|rest|salt|protein|hygiene|morning|heart"}],'
            .'"mealRecommendations":{"headline":"max 48 chars","summary":"max 180 chars","recommendations":[{"category":"protein|balance|hydration|portion|habit","title":"max 40 chars","detail":"max 140 chars"}]}'
            .'}. '
            .'Return exactly 6 NEW tips plus 2-4 mealRecommendations based on History. Context: '
            .json_encode($context, JSON_UNESCAPED_UNICODE);

        $parsed = $this->geminiJson($prompt);
        if ($parsed === null) {
            return null;
        }

        $tips = $this->normalizeTips($parsed);
        if ($tips === null) {
            return null;
        }

        return [
            'tips' => $tips,
            'mealRecommendations' => $this->normalizeMealRecommendations($parsed, $mealContext),
        ];
    }

    /**
     * @param  array<string, mixed>  $parsed
     * @return list<array{title: string, body: string, icon: string}>|null
     */
    private function normalizeTips(array $parsed): ?array
    {
        $raw = $parsed['tips'] ?? null;
        if (! is_array($raw)) {
            return null;
        }

        $allowedIcons = [
            'water', 'shade', 'food', 'walk', 'rest', 'salt', 'protein', 'hygiene', 'morning', 'heart',
        ];

        $tips = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $title = trim((string) ($row['title'] ?? ''));
            $body = trim((string) ($row['body'] ?? ''));
            if ($title === '' || $body === '') {
                continue;
            }
            $icon = strtolower(trim((string) ($row['icon'] ?? 'heart')));
            if (! in_array($icon, $allowedIcons, true)) {
                $icon = 'heart';
            }
            $tips[] = [
                'title' => Str::limit($title, 48, ''),
                'body' => Str::limit($body, 180, ''),
                'icon' => $icon,
            ];
            if (count($tips) >= 6) {
                break;
            }
        }

        return count($tips) >= 3 ? $tips : null;
    }

    /**
     * @param  array<string, mixed>  $parsed
     * @param  array<string, mixed>  $mealContext
     * @return array{
     *   headline: string,
     *   summary: string,
     *   recommendations: list<array{category: string, title: string, detail: string}>,
     *   mealsReviewed: int,
     *   recentMeals: list<string>,
     *   source: string
     * }
     */
    private function normalizeMealRecommendations(array $parsed, array $mealContext): array
    {
        $fallback = $this->ruleBasedMealRecommendations($mealContext);
        $raw = $parsed['mealRecommendations'] ?? $parsed['meal_recommendations'] ?? null;
        if (! is_array($raw)) {
            return $fallback;
        }

        $headline = trim((string) ($raw['headline'] ?? ''));
        $summary = trim((string) ($raw['summary'] ?? ''));
        $recsRaw = $raw['recommendations'] ?? null;
        if ($headline === '' || $summary === '' || ! is_array($recsRaw)) {
            return $fallback;
        }

        $allowed = ['protein', 'balance', 'hydration', 'portion', 'habit', 'energy', 'fibre'];
        $recs = [];
        foreach ($recsRaw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $title = trim((string) ($row['title'] ?? ''));
            $detail = trim((string) ($row['detail'] ?? ''));
            if ($title === '' || $detail === '') {
                continue;
            }
            $category = strtolower(trim((string) ($row['category'] ?? 'habit')));
            if (! in_array($category, $allowed, true)) {
                $category = 'habit';
            }
            $recs[] = [
                'category' => $category,
                'title' => Str::limit($title, 48, ''),
                'detail' => Str::limit($detail, 160, ''),
            ];
            if (count($recs) >= 4) {
                break;
            }
        }

        if ($recs === []) {
            return $fallback;
        }

        return [
            'headline' => Str::limit($headline, 56, ''),
            'summary' => Str::limit($summary, 200, ''),
            'recommendations' => $recs,
            'mealsReviewed' => (int) $mealContext['meals_count'],
            'recentMeals' => $mealContext['recent_meal_names'],
            'source' => 'gemini',
        ];
    }

    /**
     * @param  array<string, mixed>  $mealContext
     * @return array{
     *   headline: string,
     *   summary: string,
     *   recommendations: list<array{category: string, title: string, detail: string}>,
     *   mealsReviewed: int,
     *   recentMeals: list<string>,
     *   source: string
     * }
     */
    private function ruleBasedMealRecommendations(array $mealContext): array
    {
        $count = (int) $mealContext['meals_count'];
        $names = $mealContext['recent_meal_names'];
        $avgProtein = (float) $mealContext['avg_protein_g'];
        $avgKcal = (float) $mealContext['avg_kcal'];

        if ($count === 0) {
            return [
                'headline' => 'Start with your History',
                'summary' => 'I do not see meals in Nutrition History yet. Log a few plates and I will coach you like your personal dietitian.',
                'recommendations' => [
                    [
                        'category' => 'habit',
                        'title' => 'Log one meal today',
                        'detail' => 'Scan or add a meal so I can review protein, portions, and balance for you.',
                    ],
                    [
                        'category' => 'balance',
                        'title' => 'Build a simple plate',
                        'detail' => 'Aim for starch + protein + vegetables on your next meal—even a small green side helps.',
                    ],
                ],
                'mealsReviewed' => 0,
                'recentMeals' => [],
                'source' => 'rules',
            ];
        }

        $recs = [];
        $mealList = implode(', ', array_slice($names, 0, 4));

        if ($avgProtein < 18) {
            $recs[] = [
                'category' => 'protein',
                'title' => 'Lift protein next meal',
                'detail' => 'Recent plates average about '.round($avgProtein).'g protein. Add beans, eggs, fish, or lean meat.',
            ];
        } else {
            $recs[] = [
                'category' => 'protein',
                'title' => 'Protein looks steady',
                'detail' => 'Your recent average (~'.round($avgProtein).'g) is solid—keep pairing protein with your starches.',
            ];
        }

        if ($avgKcal > 650) {
            $recs[] = [
                'category' => 'portion',
                'title' => 'Ease the portion size',
                'detail' => 'Recent meals average ~'.round($avgKcal).' kcal. Try a slightly smaller starch mound and keep the protein.',
            ];
        } else {
            $recs[] = [
                'category' => 'energy',
                'title' => 'Keep energy even',
                'detail' => 'Your meal sizes look manageable. Spread eating across the day so energy stays even.',
            ];
        }

        $recs[] = [
            'category' => 'balance',
            'title' => 'Add a colourful side',
            'detail' => 'From History ('.$mealList.'), I still want more greens or stew vegetables beside the starch.',
        ];

        $recs[] = [
            'category' => 'hydration',
            'title' => 'Water between meals',
            'detail' => 'Sip water through the day—especially after denser plates—to support digestion and focus.',
        ];

        return [
            'headline' => 'Coaching from your History',
            'summary' => 'I reviewed '.$count.' logged meal'.($count === 1 ? '' : 's').' from the last week'
                .($mealList !== '' ? " (including {$mealList})" : '')
                .' and shaped these dietitian recommendations for you.',
            'recommendations' => array_slice($recs, 0, 4),
            'mealsReviewed' => $count,
            'recentMeals' => $names,
            'source' => 'rules',
        ];
    }

    /**
     * @return array{
     *   days: int,
     *   meals_count: int,
     *   total_kcal: int,
     *   avg_kcal: float,
     *   avg_protein_g: float,
     *   avg_carbs_g: float,
     *   avg_fat_g: float,
     *   recent_meal_names: list<string>,
     *   fingerprint: string
     * }
     */
    private function mealHistoryContext(?User $user): array
    {
        $empty = [
            'days' => 7,
            'meals_count' => 0,
            'total_kcal' => 0,
            'avg_kcal' => 0.0,
            'avg_protein_g' => 0.0,
            'avg_carbs_g' => 0.0,
            'avg_fat_g' => 0.0,
            'recent_meal_names' => [],
            'fingerprint' => 'none',
        ];

        if ($user === null || ! Schema::hasTable('meal_logs')) {
            return $empty;
        }

        $from = now()->subDays(6)->startOfDay();
        $to = now()->endOfDay();

        $logs = MealLog::query()
            ->where('user_id', $user->id)
            ->whereBetween('eaten_at', [$from, $to])
            ->orderByDesc('eaten_at')
            ->limit(40)
            ->get(['name', 'calories', 'protein_g', 'carbs_g', 'fat_g', 'eaten_at']);

        if ($logs->isEmpty()) {
            return $empty;
        }

        $count = $logs->count();
        $totalKcal = (int) $logs->sum(fn ($m) => (int) ($m->calories ?? 0));
        $totalProtein = (float) $logs->sum(fn ($m) => (float) ($m->protein_g ?? 0));
        $totalCarbs = (float) $logs->sum(fn ($m) => (float) ($m->carbs_g ?? 0));
        $totalFat = (float) $logs->sum(fn ($m) => (float) ($m->fat_g ?? 0));

        $names = $logs
            ->pluck('name')
            ->map(fn ($n) => trim((string) $n))
            ->filter()
            ->unique(fn ($n) => strtolower($n))
            ->take(8)
            ->values()
            ->all();

        return [
            'days' => 7,
            'meals_count' => $count,
            'total_kcal' => $totalKcal,
            'avg_kcal' => round($totalKcal / max(1, $count), 1),
            'avg_protein_g' => round($totalProtein / max(1, $count), 1),
            'avg_carbs_g' => round($totalCarbs / max(1, $count), 1),
            'avg_fat_g' => round($totalFat / max(1, $count), 1),
            'recent_meal_names' => $names,
            'fingerprint' => md5(json_encode([
                $count,
                $totalKcal,
                $names,
            ], JSON_THROW_ON_ERROR)),
        ];
    }

    /**
     * @return list<array{title: string, body: string, icon: string}>
     */
    private function localTips(): array
    {
        return [
            [
                'title' => 'Sip through the day',
                'body' => 'As your dietitian, I\'d rather you take small sips all day than wait until thirst hits—especially in the heat.',
                'icon' => 'water',
            ],
            [
                'title' => 'Shade over strain',
                'body' => 'When the sun is fierce, build shade breaks into your walk. I want you steady outdoors, not drained.',
                'icon' => 'shade',
            ],
            [
                'title' => 'Eat more colour',
                'body' => 'Add leafy greens, garden eggs, or tomatoes to today\'s plate—I coach colour because it quietly lifts iron and fibre.',
                'icon' => 'food',
            ],
            [
                'title' => 'Pace your steps',
                'body' => 'If the air feels dusty, keep outdoor walks shorter and easy. Your indoor steps still count toward the goal I set with you.',
                'icon' => 'walk',
            ],
            [
                'title' => 'Rest is recovery',
                'body' => 'Aim for solid sleep tonight. As your coach, I know rest steadies appetite, mood, and how hard movement feels tomorrow.',
                'icon' => 'rest',
            ],
            [
                'title' => 'Salt with care',
                'body' => 'Seasoned meals are fine—just go easy on extra table salt if we\'re watching your blood pressure habits.',
                'icon' => 'salt',
            ],
            [
                'title' => 'Protein at meals',
                'body' => 'Pair your starch with beans, eggs, fish, or lean meat so your energy lasts between meals.',
                'icon' => 'protein',
            ],
            [
                'title' => 'Wash hands, stay well',
                'body' => 'Clean hands before meals and after being out—simple hygiene that keeps your nutrition plan on track.',
                'icon' => 'hygiene',
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function geminiJson(string $prompt): ?array
    {
        $apiKey = trim((string) config('services.food_scan.gemini_api_key', ''));
        if ($apiKey === '') {
            return null;
        }

        $model = (string) config('services.food_scan.gemini_model', 'gemini-2.0-flash');
        $timeout = (int) config('services.dietitian.gemini_timeout', 45);
        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent";

        try {
            $response = Http::timeout($timeout)
                ->withQueryParameters(['key' => $apiKey])
                ->post($url, [
                    'contents' => [
                        ['parts' => [['text' => $prompt]]],
                    ],
                    'generationConfig' => [
                        'temperature' => 0.8,
                        'responseMimeType' => 'application/json',
                    ],
                ]);
        } catch (\Throwable $e) {
            Log::warning('Safety tips Gemini request failed', ['error' => $e->getMessage()]);

            return null;
        }

        if (! $response->successful()) {
            Log::warning('Safety tips Gemini HTTP error', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return null;
        }

        $text = data_get($response->json(), 'candidates.0.content.parts.0.text');
        if (! is_string($text) || trim($text) === '') {
            return null;
        }

        $decoded = json_decode(trim($text), true);

        return is_array($decoded) ? $decoded : null;
    }
}
