<?php

namespace App\Services;

use App\Models\User;
use App\Support\BodyMetrics;
use App\Support\GhanaianMealSuggestions;
use App\Support\HealthAssistantCoaching;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Virtual dietitian: Gemini Flash when configured, rule-based Ghanaian coaching as fallback.
 */
class DietitianAdviceService
{
    /**
     * @param  list<string>  $todayMealNames
     * @param  array{dailyCaloriesTarget: int, proteinG: int, carbsG: int, fatG: int}  $targets
     * @return array{
     *   headline: string,
     *   summary: string,
     *   recommendations: list<array{category: string, title: string, detail: string}>,
     *   nextMeal: array{suggestion: string, reason: string}|null,
     *   hydrationTip: string|null,
     *   portionTip: string|null,
     *   bodyMetrics: array<string, mixed>,
     *   source: string
     * }
     */
    public function dailyAdvice(
        User $user,
        int $consumedKcal,
        int $consumedProteinG,
        int $consumedCarbsG,
        int $consumedFatG,
        array $targets,
        int $mealsLoggedToday,
        int $mealsLogged7Days,
        array $todayMealNames = [],
        ?string $alertTitle = null,
        ?string $alertMessage = null,
        int $todaySteps = 0,
        int $stepGoal = 0,
        int $burnedKcal = 0,
    ): array {
        $weightKg = is_numeric($user->weight) ? (float) $user->weight : null;
        $heightCm = is_numeric($user->height) ? (float) $user->height : null;
        $goal = trim((string) ($user->goal ?? ''));
        $targetKcal = max(0, (int) ($targets['dailyCaloriesTarget'] ?? 0));

        $bodyMetrics = BodyMetrics::snapshot(
            weightKg: $weightKg,
            heightCm: $heightCm,
            goal: $goal,
            todaySteps: $todaySteps,
            stepGoal: $stepGoal,
            burnedKcal: $burnedKcal,
            consumedKcal: $consumedKcal,
            dailyCaloriesTarget: $targetKcal,
        );

        $rules = $this->ruleBasedDailyAdvice(
            $user,
            $consumedKcal,
            $consumedProteinG,
            $consumedCarbsG,
            $consumedFatG,
            $targets,
            $mealsLoggedToday,
            $mealsLogged7Days,
            $todayMealNames,
            $alertTitle,
            $alertMessage,
            $todaySteps,
            $stepGoal,
            $burnedKcal,
            $bodyMetrics,
        );

        $gemini = $this->tryGeminiDailyAdvice(
            $user,
            $consumedKcal,
            $consumedProteinG,
            $consumedCarbsG,
            $consumedFatG,
            $targets,
            $mealsLoggedToday,
            $mealsLogged7Days,
            $todayMealNames,
            $alertTitle,
            $alertMessage,
            $todaySteps,
            $stepGoal,
            $burnedKcal,
            $bodyMetrics,
        );

        if ($gemini !== null) {
            return array_merge($gemini, [
                'bodyMetrics' => $bodyMetrics,
                'source' => 'gemini',
            ]);
        }

        return array_merge($rules, [
            'bodyMetrics' => $bodyMetrics,
            'source' => 'rules',
        ]);
    }

    /**
     * @return array{insight: string, pairing: string|null, portion: string|null, source: string}
     */
    public function mealAdvice(
        string $foodName,
        ?string $className,
        int $calories,
        int $proteinG,
        int $carbsG,
        int $fatG,
        string $goal = '',
        int $remainingKcal = 0,
        int $proteinGap = 0,
        ?User $user = null,
    ): array {
        $rules = $this->ruleBasedMealAdvice(
            $foodName,
            $className,
            $calories,
            $proteinG,
            $carbsG,
            $fatG,
            $goal,
            $remainingKcal,
            $proteinGap,
        );

        $gemini = $this->tryGeminiMealAdvice(
            $foodName,
            $className,
            $calories,
            $proteinG,
            $carbsG,
            $fatG,
            $goal,
            $remainingKcal,
            $proteinGap,
            $user,
        );

        if ($gemini !== null) {
            return array_merge($gemini, ['source' => 'gemini']);
        }

        return array_merge($rules, ['source' => 'rules']);
    }

    /**
     * @param  list<string>  $todayMealNames
     * @param  array{dailyCaloriesTarget: int, proteinG: int, carbsG: int, fatG: int}  $targets
     * @return array{
     *   headline: string,
     *   summary: string,
     *   recommendations: list<array{category: string, title: string, detail: string}>,
     *   nextMeal: array{suggestion: string, reason: string}|null,
     *   hydrationTip: string|null,
     *   portionTip: string|null
     * }
     */
    private function ruleBasedDailyAdvice(
        User $user,
        int $consumedKcal,
        int $consumedProteinG,
        int $consumedCarbsG,
        int $consumedFatG,
        array $targets,
        int $mealsLoggedToday,
        int $mealsLogged7Days,
        array $todayMealNames,
        ?string $alertTitle,
        ?string $alertMessage,
        int $todaySteps,
        int $stepGoal,
        int $burnedKcal,
        array $bodyMetrics,
    ): array {
        $name = $this->firstName((string) $user->name);
        $goal = trim((string) ($user->goal ?? ''));
        $targetKcal = max(0, (int) ($targets['dailyCaloriesTarget'] ?? 0));
        $targetP = max(0, (int) ($targets['proteinG'] ?? 0));
        $targetC = max(0, (int) ($targets['carbsG'] ?? 0));
        $targetF = max(0, (int) ($targets['fatG'] ?? 0));

        $netKcal = max(0, $consumedKcal - max(0, $burnedKcal));
        $remainingKcal = $targetKcal > 0 ? $targetKcal - $netKcal : 0;
        $proteinGap = $targetP > 0 ? $targetP - $consumedProteinG : 0;
        $carbsGap = $targetC > 0 ? $targetC - $consumedCarbsG : 0;
        $fatGap = $targetF > 0 ? $targetF - $consumedFatG : 0;
        $bmi = is_numeric($bodyMetrics['bmi'] ?? null) ? (float) $bodyMetrics['bmi'] : null;

        $recommendations = [];
        $headline = "Let's keep your nutrition steady today, $name.";
        $summary = "I'm reviewing your meals, steps, and targets to give practical Ghana-friendly guidance—not strict dieting.";

        $bmiLine = BodyMetrics::bmiCoachingLine($bmi, $goal);
        if ($bmiLine !== null) {
            $recommendations[] = [
                'category' => 'body',
                'title' => $bmi !== null ? 'BMI '.number_format($bmi, 1).' — '.($bodyMetrics['bmiCategory'] ?? '')
                    : 'Body profile',
                'detail' => $bmiLine,
            ];
        }

        foreach (HealthAssistantCoaching::recommendationsFor($user) as $assistantRec) {
            $recommendations[] = $assistantRec;
        }

        if ($alertTitle && $alertMessage && ! str_contains(strtolower($alertTitle), 'no alert')) {
            $recommendations[] = [
                'category' => 'environment',
                'title' => $alertTitle,
                'detail' => $alertMessage,
            ];
            $headline = "$name, adjust today's plan for the weather.";
            $summary = 'Outdoor conditions matter for appetite and activity. Lighter meals and steady hydration help you stay comfortable.';
        }

        if ($mealsLoggedToday === 0) {
            $recommendations[] = [
                'category' => 'habit',
                'title' => 'Log your first meal',
                'detail' => $mealsLogged7Days > 0
                    ? "You've logged $mealsLogged7Days meals this week—scan or log breakfast so I can balance the rest of your day."
                    : 'Start with whatever you eat next. Consistent logging is the single best way to improve portion awareness.',
            ];
            $headline = "$name, I'm ready when you log your first meal.";
        } elseif ($mealsLoggedToday === 1) {
            $recommendations[] = [
                'category' => 'habit',
                'title' => 'Build a full day picture',
                'detail' => 'One meal logged is a good start. Aim for at least two logs today so protein and calories stay on track.',
            ];
        } else {
            $recommendations[] = [
                'category' => 'habit',
                'title' => 'Great logging consistency',
                'detail' => "$mealsLoggedToday meals logged today—this helps me give sharper recommendations.",
            ];
        }

        if ($targetKcal > 0) {
            $burnedNote = $burnedKcal > 0
                ? " Your steps burned about {$burnedKcal} kcal today, so I'm using net intake (food minus activity)."
                : '';

            if ($remainingKcal > 400) {
                $recommendations[] = [
                    'category' => 'calories',
                    'title' => 'Room left in your budget',
                    'detail' => "About $remainingKcal kcal remaining after activity. ".$this->goalCalorieHint($goal, 'remaining').$burnedNote,
                ];
                $headline = $goal === 'Lose weight'
                    ? "$name, you still have calorie room—use it wisely."
                    : "$name, fuel the rest of your day thoughtfully.";
            } elseif ($remainingKcal < -300) {
                $over = abs($remainingKcal);
                $recommendations[] = [
                    'category' => 'calories',
                    'title' => "Above today's target",
                    'detail' => "You're about $over kcal over target (net of steps). Choose a lighter dinner—kenkey with grilled fish, light soup, or a smaller waakye portion.$burnedNote",
                ];
                $headline = "$name, let's lighten the next meal.";
            } else {
                $recommendations[] = [
                    'category' => 'calories',
                    'title' => 'On track with calories',
                    'detail' => 'Your net intake is close to target after food and steps. Maintain steady portions at the next meal.'.$burnedNote,
                ];
            }
        }

        if ($stepGoal > 0) {
            $stepsPct = (int) round(($todaySteps / max(1, $stepGoal)) * 100);
            if ($todaySteps >= $stepGoal) {
                $recommendations[] = [
                    'category' => 'activity',
                    'title' => 'Step goal reached',
                    'detail' => "You've hit {$todaySteps} steps—that activity earns you a little extra calorie room and supports your {$goal} goal.",
                ];
            } elseif ($stepsPct < 50) {
                $recommendations[] = [
                    'category' => 'activity',
                    'title' => 'Move a bit more today',
                    'detail' => "{$todaySteps} of {$stepGoal} steps so far. A short walk before supper helps balance chop bar meals and burns extra energy.",
                ];
            } else {
                $recommendations[] = [
                    'category' => 'activity',
                    'title' => 'Steps progressing',
                    'detail' => "{$todaySteps} of {$stepGoal} steps ({$stepsPct}%). Keep moving—activity shapes how much room you have for the next meal.",
                ];
            }
        }

        if ($proteinGap > 15) {
            $recommendations[] = [
                'category' => 'protein',
                'title' => 'Boost protein next',
                'detail' => "You need roughly {$proteinGap}g more protein today. Try banku and tilapia, waakye with egg and fish, or red-red with plantain.",
            ];
        } elseif ($targetP > 0 && $proteinGap <= 0) {
            $recommendations[] = [
                'category' => 'protein',
                'title' => 'Protein goal met',
                'detail' => 'Good protein intake so far. Pair your next meal with vegetables for balance.',
            ];
        }

        if ($carbsGap > 40 && $goal === 'Lose weight') {
            $recommendations[] = [
                'category' => 'carbs',
                'title' => 'Watch starch portions',
                'detail' => 'For weight loss, keep fufu, banku, and large rice portions to about a fist-size serving and add extra kontomire or salad.',
            ];
        }

        if ($fatGap > 20) {
            $recommendations[] = [
                'category' => 'fat',
                'title' => 'Healthy fats still available',
                'detail' => 'Groundnut soup, avocado, or a small handful of peanuts can cover healthy fats without deep-fried extras.',
            ];
        }

        foreach ($todayMealNames as $mealName) {
            $foodTip = $this->foodSpecificTip($mealName);
            if ($foodTip !== null) {
                $recommendations[] = $foodTip;
                break;
            }
        }

        $nextMeal = GhanaianMealSuggestions::nextMeal(
            mealsLoggedToday: $mealsLoggedToday,
            goal: $goal,
            remainingKcal: $remainingKcal,
            proteinGap: $proteinGap,
        );
        $hydration = 'Aim for 6–8 glasses of water today. Extra important with jollof, waakye, or spicy stews.';
        $portionTip = BodyMetrics::portionHint($bmi, $goal);

        if ($goal === 'Lose weight') {
            $summary = "As your dietitian coach, I'm focusing on portion control, lean protein, and fewer fried sides while keeping familiar Ghanaian foods.";
        } elseif ($goal === 'Gain weight') {
            $summary = "I'm prioritizing calorie-dense but nutritious choices—banku with fish, groundnut soup, and regular snacks between meals.";
        } elseif ($goal !== '') {
            $summary = "I'm aligning today's meals with your goal: $goal. Small, steady changes beat extreme restrictions.";
        }

        return [
            'headline' => $headline,
            'summary' => $summary,
            'recommendations' => array_slice($recommendations, 0, 6),
            'nextMeal' => $nextMeal,
            'hydrationTip' => $hydration,
            'portionTip' => $portionTip,
        ];
    }

    /**
     * @return array{insight: string, pairing: string|null, portion: string|null}
     */
    private function ruleBasedMealAdvice(
        string $foodName,
        ?string $className,
        int $calories,
        int $proteinG,
        int $carbsG,
        int $fatG,
        string $goal,
        int $remainingKcal,
        int $proteinGap,
    ): array {
        $slug = Str::lower(trim($className ?? $foodName));
        $display = trim($foodName) !== '' ? trim($foodName) : 'this meal';

        $specific = $this->mealInsightForSlug($slug, $goal);
        $insight = $specific ?? $this->genericMealInsight($display, $calories, $goal, $remainingKcal, $proteinGap);

        return [
            'insight' => Str::limit($insight, 255, ''),
            'pairing' => GhanaianMealSuggestions::pairingForFood($slug) ?? $this->pairingSuggestion($slug),
            'portion' => $this->portionNote($slug, $calories),
        ];
    }

    /**
     * @param  list<string>  $todayMealNames
     * @param  array{dailyCaloriesTarget: int, proteinG: int, carbsG: int, fatG: int}  $targets
     * @return array{
     *   headline: string,
     *   summary: string,
     *   recommendations: list<array{category: string, title: string, detail: string}>,
     *   nextMeal: array{suggestion: string, reason: string}|null,
     *   hydrationTip: string|null,
     *   portionTip: string|null
     * }|null
     */
    private function tryGeminiDailyAdvice(
        User $user,
        int $consumedKcal,
        int $consumedProteinG,
        int $consumedCarbsG,
        int $consumedFatG,
        array $targets,
        int $mealsLoggedToday,
        int $mealsLogged7Days,
        array $todayMealNames,
        ?string $alertTitle,
        ?string $alertMessage,
        int $todaySteps,
        int $stepGoal,
        int $burnedKcal,
        array $bodyMetrics,
    ): ?array {
        $context = [
            'client' => [
                'name' => $this->firstName((string) $user->name),
                'goal' => (string) ($user->goal ?? ''),
                'age' => $user->age,
                'gender' => $user->gender,
                'weight_kg' => $user->weight,
                'height_cm' => $user->height,
                'activity_level' => $user->activity_level,
                'bmi' => $bodyMetrics['bmi'] ?? null,
                'bmi_category' => $bodyMetrics['bmiCategory'] ?? null,
            ],
            'today' => [
                'consumed_kcal' => $consumedKcal,
                'burned_kcal_from_steps' => $burnedKcal,
                'net_kcal' => $bodyMetrics['netKcal'] ?? max(0, $consumedKcal - $burnedKcal),
                'steps' => $todaySteps,
                'step_goal' => $stepGoal,
                'consumed_protein_g' => $consumedProteinG,
                'consumed_carbs_g' => $consumedCarbsG,
                'consumed_fat_g' => $consumedFatG,
                'target_kcal' => (int) ($targets['dailyCaloriesTarget'] ?? 0),
                'net_remaining_kcal' => $bodyMetrics['netRemainingKcal'] ?? null,
                'target_protein_g' => (int) ($targets['proteinG'] ?? 0),
                'target_carbs_g' => (int) ($targets['carbsG'] ?? 0),
                'target_fat_g' => (int) ($targets['fatG'] ?? 0),
                'meals_logged_today' => $mealsLoggedToday,
                'meals_logged_7_days' => $mealsLogged7Days,
                'meal_names_today' => $todayMealNames,
                'environment_alert' => ($alertTitle && $alertMessage && ! str_contains(strtolower($alertTitle), 'no alert'))
                    ? ['title' => $alertTitle, 'message' => $alertMessage]
                    : null,
            ],
        ];

        $prompt = 'You are a warm, professional registered dietitian coaching a Ghanaian client through a mobile app. '
            .implode(' ', GhanaianMealSuggestions::geminiAuthenticityRules()).' '
            .'Factor in BMI, goal, steps burned, and net calories (food minus step burn). Be practical—not preachy. No medical diagnosis. JSON only with this shape: '
            .'{"headline":"...","summary":"2 sentences max","recommendations":[{"category":"habit|calories|protein|food|environment","title":"...","detail":"..."}],'
            .'"nextMeal":{"suggestion":"Ghanaian dish","reason":"..."},"hydrationTip":"...","portionTip":"..."}. '
            .'Up to 5 recommendations. nextMeal can be null if unclear. Client data: '
            .json_encode($context, JSON_UNESCAPED_UNICODE);

        $parsed = $this->geminiJson($prompt);
        if ($parsed === null) {
            return null;
        }

        return $this->normalizeDailyAdvicePayload($parsed);
    }

    /**
     * @return array{insight: string, pairing: string|null, portion: string|null}|null
     */
    private function tryGeminiMealAdvice(
        string $foodName,
        ?string $className,
        int $calories,
        int $proteinG,
        int $carbsG,
        int $fatG,
        string $goal,
        int $remainingKcal,
        int $proteinGap,
        ?User $user,
    ): ?array {
        $context = [
            'food_name' => $foodName,
            'class_name' => $className,
            'calories' => $calories,
            'protein_g' => $proteinG,
            'carbs_g' => $carbsG,
            'fat_g' => $fatG,
            'goal' => $goal,
            'remaining_kcal_today' => $remainingKcal,
            'protein_gap_g' => $proteinGap,
            'client_name' => $user ? $this->firstName((string) $user->name) : null,
        ];

        $prompt = 'You are a Ghanaian dietitian. Give brief coaching for this logged/scanned meal. '
            .implode(' ', GhanaianMealSuggestions::geminiAuthenticityRules()).' '
            .'JSON only: {"insight":"max 220 chars, friendly 2nd person","pairing":"optional realistic side pairing","portion":"optional portion note"}. '
            .'Data: '
            .json_encode($context, JSON_UNESCAPED_UNICODE);

        $parsed = $this->geminiJson($prompt);
        if ($parsed === null || ! isset($parsed['insight'])) {
            return null;
        }

        return [
            'insight' => Str::limit(trim((string) $parsed['insight']), 255, ''),
            'pairing' => isset($parsed['pairing']) && is_string($parsed['pairing']) && trim($parsed['pairing']) !== ''
                ? Str::limit(trim($parsed['pairing']), 200, '')
                : null,
            'portion' => isset($parsed['portion']) && is_string($parsed['portion']) && trim($parsed['portion']) !== ''
                ? Str::limit(trim($parsed['portion']), 200, '')
                : null,
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

        $model = (string) config('services.food_scan.gemini_model', 'gemini-2.5-flash');
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
                        'temperature' => 0.45,
                        'responseMimeType' => 'application/json',
                    ],
                ]);
        } catch (\Throwable $e) {
            Log::warning('Dietitian Gemini request failed', ['error' => $e->getMessage()]);

            return null;
        }

        if (! $response->successful()) {
            Log::warning('Dietitian Gemini HTTP error', ['status' => $response->status(), 'body' => $response->body()]);

            return null;
        }

        $text = data_get($response->json(), 'candidates.0.content.parts.0.text');
        if (! is_string($text) || trim($text) === '') {
            return null;
        }

        $decoded = json_decode(trim($text), true);

        return is_array($decoded) ? $decoded : null;
    }

    /**
     * @param  array<string, mixed>  $parsed
     * @return array{
     *   headline: string,
     *   summary: string,
     *   recommendations: list<array{category: string, title: string, detail: string}>,
     *   nextMeal: array{suggestion: string, reason: string}|null,
     *   hydrationTip: string|null,
     *   portionTip: string|null
     * }|null
     */
    private function normalizeDailyAdvicePayload(array $parsed): ?array
    {
        $headline = trim((string) ($parsed['headline'] ?? ''));
        $summary = trim((string) ($parsed['summary'] ?? ''));
        if ($headline === '' || $summary === '') {
            return null;
        }

        $recommendations = [];
        $rawRecs = $parsed['recommendations'] ?? [];
        if (is_array($rawRecs)) {
            foreach ($rawRecs as $row) {
                if (! is_array($row)) {
                    continue;
                }
                $title = trim((string) ($row['title'] ?? ''));
                $detail = trim((string) ($row['detail'] ?? ''));
                if ($title === '' || $detail === '') {
                    continue;
                }
                $recommendations[] = [
                    'category' => trim((string) ($row['category'] ?? 'general')),
                    'title' => Str::limit($title, 80, ''),
                    'detail' => Str::limit($detail, 280, ''),
                ];
            }
        }

        $nextMeal = null;
        $rawNext = $parsed['nextMeal'] ?? null;
        if (is_array($rawNext)) {
            $suggestion = trim((string) ($rawNext['suggestion'] ?? ''));
            $reason = trim((string) ($rawNext['reason'] ?? ''));
            if ($suggestion !== '' && $reason !== '') {
                $nextMeal = [
                    'suggestion' => Str::limit($suggestion, 120, ''),
                    'reason' => Str::limit($reason, 200, ''),
                ];
            }
        }

        return [
            'headline' => Str::limit($headline, 120, ''),
            'summary' => Str::limit($summary, 320, ''),
            'recommendations' => array_slice($recommendations, 0, 6),
            'nextMeal' => $nextMeal,
            'hydrationTip' => isset($parsed['hydrationTip']) && is_string($parsed['hydrationTip'])
                ? Str::limit(trim($parsed['hydrationTip']), 200, '')
                : null,
            'portionTip' => isset($parsed['portionTip']) && is_string($parsed['portionTip'])
                ? Str::limit(trim($parsed['portionTip']), 200, '')
                : null,
        ];
    }

    private function firstName(string $full): string
    {
        $parts = preg_split('/\s+/', trim($full)) ?: [];
        $first = $parts[0] ?? '';

        return $first !== '' ? $first : 'there';
    }

    private function goalCalorieHint(string $goal, string $context): string
    {
        return match ($goal) {
            'Lose weight' => $context === 'remaining'
                ? 'Prioritize grilled protein, kontomire, and smaller starch portions.'
                : 'Keep portions modest and limit fried sides.',
            'Gain weight' => 'Add a protein-rich snack—peanuts, milk, or an extra fish portion.',
            default => 'Balance starch, protein, and vegetables at your next sitting.',
        };
    }

    /**
     * @return array{category: string, title: string, detail: string}|null
     */
    private function foodSpecificTip(string $mealName): ?array
    {
        $slug = Str::lower($mealName);

        if (str_contains($slug, 'jollof')) {
            return [
                'category' => 'food',
                'title' => 'About your jollof',
                'detail' => "Jollof is energy-dense. Pair with salad or grilled chicken and skip extra oily sides if you're watching calories.",
            ];
        }
        if (str_contains($slug, 'banku') || str_contains($slug, 'fufu') || str_contains($slug, 'kenkey')) {
            return [
                'category' => 'food',
                'title' => 'Starch portion check',
                'detail' => 'One ball of banku, fufu, or kenkey with the right soup or fish is how Ghanaians plate it—not double starch.',
            ];
        }
        if (str_contains($slug, 'waakye')) {
            return [
                'category' => 'food',
                'title' => 'Waakye chop balance',
                'detail' => 'Pick your sides like at the vendor—shito, gari, egg, plantain—but you do not need every topping every time.',
            ];
        }
        if (str_contains($slug, 'kelewele') || str_contains($slug, 'fried')) {
            return [
                'category' => 'food',
                'title' => 'Fried foods',
                'detail' => 'Fried plantain and kelewele are tasty treats. Keep them as a side, not the main plate, especially in the evening.',
            ];
        }

        return null;
    }

    private function pairingSuggestion(string $slug): ?string
    {
        return GhanaianMealSuggestions::pairingForFood($slug);
    }

    /**
     * @return string|null
     */
    private function mealInsightForSlug(string $slug, string $goal): ?string
    {
        $tips = [
            'jollof' => 'Jollof is a celebration dish—enjoy it with protein on the side and watch oily extras if weight loss is your goal.',
            'banku' => 'Banku goes with okro stew or grilled tilapia and shito—that is the chop people know.',
            'fufu' => 'Fufu with light soup or groundnut soup—one medium ball is enough for most people.',
            'kenkey' => 'Kenkey and fried fish with shito is the classic supper—save kenkey for evening.',
            'waakye' => 'Waakye chop: add shito, gari, egg, plantain—how the vendor serves it.',
            'kelewele' => 'Kelewele is a side chop—pair with rice, jollof, or beans, not as the whole meal.',
            'plantain' => 'Fried plantain with beans stew (red-red) or beside waakye—not eaten alone as dinner.',
            'beans' => 'Gobe/red-red with ripe plantain is a proper plate—filling and very local.',
            'rice' => 'Rice and stew from the chop bar, with salad or kontomire if you have it.',
            'yam' => 'Boiled yam (ampesi) with kontomire stew or palm oil stew.',
            'kokonte' => 'Kokonte with groundnut or palm nut soup—mind the portion.',
            'koose' => 'Koose goes with Hausa koko in the morning or afternoon—not as a random supper side.',
            'hausa-koko' => 'Koko is drunk with koose or bofrot—morning or afternoon porridge, not a dinner plate.',
            'chicken' => 'Stew chicken with jollof or plain rice is how chop bars serve it.',
            'meat' => 'Goat or beef in light soup or stew—with fufu or rice.',
            'egg-pepper' => 'Eggs with bread or on waakye—not a strange solo dinner.',
        ];

        foreach ($tips as $key => $tip) {
            if (str_contains($slug, $key) || str_contains($slug, str_replace('-', ' ', $key))) {
                if ($goal === 'Lose weight' && in_array($key, ['kelewele', 'koose', 'kenkey'], true)) {
                    return $tip.' For your goal, keep this as an occasional treat.';
                }

                return $tip;
            }
        }

        return null;
    }

    private function portionNote(string $slug, int $calories): ?string
    {
        if ($calories >= 800) {
            return 'This looks like a full chop bar portion—next time one ball of swallow or a smaller waakye base may be enough.';
        }
        if (str_contains($slug, 'fufu') || str_contains($slug, 'banku') || str_contains($slug, 'kenkey')) {
            return 'One ball is the usual serving—two balls is “I am very hungry” territory.';
        }

        return null;
    }

    private function genericMealInsight(
        string $display,
        int $calories,
        string $goal,
        int $remainingKcal,
        int $proteinGap,
    ): string {
        if ($calories >= 700) {
            return "$display is a hearty chop. Drink water and make your next plate lighter on starch.";
        }
        if ($proteinGap > 25) {
            return "Good logging $display. Your day still needs protein—banku and tilapia, waakye with egg, or gobe next.";
        }
        if ($goal === 'Lose weight' && $remainingKcal < 0) {
            return "$display logged. You're above target—a short walk and kenkey with grilled fish or light soup helps.";
        }

        return "Nice work logging $display. Consistent tracking is how we fine-tune your chop bar meal plan.";
    }
}
