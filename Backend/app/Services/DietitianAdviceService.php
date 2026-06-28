<?php

namespace App\Services;

use App\Models\User;
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
    ): array {
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
        );

        if ($gemini !== null) {
            return array_merge($gemini, ['source' => 'gemini']);
        }

        return array_merge($rules, ['source' => 'rules']);
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
    ): array {
        $name = $this->firstName((string) $user->name);
        $goal = trim((string) ($user->goal ?? ''));
        $targetKcal = max(0, (int) ($targets['dailyCaloriesTarget'] ?? 0));
        $targetP = max(0, (int) ($targets['proteinG'] ?? 0));
        $targetC = max(0, (int) ($targets['carbsG'] ?? 0));
        $targetF = max(0, (int) ($targets['fatG'] ?? 0));

        $remainingKcal = $targetKcal > 0 ? $targetKcal - $consumedKcal : 0;
        $proteinGap = $targetP > 0 ? $targetP - $consumedProteinG : 0;
        $carbsGap = $targetC > 0 ? $targetC - $consumedCarbsG : 0;
        $fatGap = $targetF > 0 ? $targetF - $consumedFatG : 0;

        $recommendations = [];
        $headline = "Let's keep your nutrition steady today, $name.";
        $summary = "I'm reviewing your meals and targets to give practical, Ghana-friendly guidance—not strict dieting.";

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
            if ($remainingKcal > 400) {
                $recommendations[] = [
                    'category' => 'calories',
                    'title' => 'Room left in your budget',
                    'detail' => "About $remainingKcal kcal remaining. ".$this->goalCalorieHint($goal, 'remaining'),
                ];
                $headline = $goal === 'Lose weight'
                    ? "$name, you still have calorie room—use it wisely."
                    : "$name, fuel the rest of your day thoughtfully.";
            } elseif ($remainingKcal < -300) {
                $over = abs($remainingKcal);
                $recommendations[] = [
                    'category' => 'calories',
                    'title' => "Above today's target",
                    'detail' => "You're about $over kcal over target. Choose a lighter dinner—vegetable soup, grilled fish, or a smaller starch portion.",
                ];
                $headline = "$name, let's lighten the next meal.";
            } else {
                $recommendations[] = [
                    'category' => 'calories',
                    'title' => 'On track with calories',
                    'detail' => 'Your intake is close to target. Maintain steady portions at the next meal.',
                ];
            }
        }

        if ($proteinGap > 15) {
            $recommendations[] = [
                'category' => 'protein',
                'title' => 'Boost protein next',
                'detail' => "You need roughly {$proteinGap}g more protein today. Try tilapia with banku, beans stew (gobe), boiled eggs, or chicken light soup.",
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

        $nextMeal = $this->suggestNextMeal($goal, $remainingKcal, $proteinGap, $carbsGap, $mealsLoggedToday);
        $hydration = 'Aim for 6–8 glasses of water today. Extra important with jollof, waakye, or spicy stews.';
        $portionTip = 'Use your palm for protein, fist for starches, and two cupped hands for vegetables when plating Ghanaian meals.';

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
            'pairing' => $this->pairingSuggestion($slug),
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
            ],
            'today' => [
                'consumed_kcal' => $consumedKcal,
                'consumed_protein_g' => $consumedProteinG,
                'consumed_carbs_g' => $consumedCarbsG,
                'consumed_fat_g' => $consumedFatG,
                'target_kcal' => (int) ($targets['dailyCaloriesTarget'] ?? 0),
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
            .'Use familiar local foods (banku, fufu, jollof, waakye, kenkey, kontomire, gobe, tilapia, groundnut soup). '
            .'Be practical—not preachy. No medical diagnosis. JSON only with this shape: '
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
            .'JSON only: {"insight":"max 220 chars, friendly 2nd person","pairing":"optional side pairing","portion":"optional portion note"}. '
            .'Reference local foods when relevant. No diagnosis. Data: '
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
                'detail' => 'Banku, fufu, and kenkey fill you fast. One moderate ball with lean soup or fish is usually enough per meal.',
            ];
        }
        if (str_contains($slug, 'waakye')) {
            return [
                'category' => 'food',
                'title' => 'Waakye balance',
                'detail' => "Waakye packs carbs and beans—great for energy. Add egg or fish for protein and go easy on extra gari if you're not very active today.",
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

    /**
     * @return array{suggestion: string, reason: string}|null
     */
    private function suggestNextMeal(
        string $goal,
        int $remainingKcal,
        int $proteinGap,
        int $carbsGap,
        int $mealsLoggedToday,
    ): ?array {
        if ($mealsLoggedToday === 0) {
            return [
                'suggestion' => 'Hausa koko with koose or boiled eggs',
                'reason' => "A familiar Ghanaian breakfast that's light but gives protein to start the day.",
            ];
        }

        if ($proteinGap > 20) {
            return [
                'suggestion' => 'Grilled tilapia with kontomire stew (no extra oil)',
                'reason' => "You're low on protein—fish and leafy greens close the gap without heavy starch.",
            ];
        }

        if ($remainingKcal < 0) {
            return [
                'suggestion' => 'Light groundnut soup with a small fufu portion',
                'reason' => 'Nutrient-rich but you can keep the fufu modest after a higher-calorie day.',
            ];
        }

        if ($goal === 'Gain weight' && $remainingKcal > 500) {
            return [
                'suggestion' => 'Banku with grilled fish and a groundnut snack',
                'reason' => 'Calorie-dense and protein-forward for healthy weight gain.',
            ];
        }

        if ($carbsGap > 30) {
            return [
                'suggestion' => 'Waakye with boiled egg and salad',
                'reason' => 'Steady carbs from rice and beans plus fiber from vegetables.',
            ];
        }

        return [
            'suggestion' => 'Vegetable soup with a palm-sized rice or yam portion',
            'reason' => 'Balanced plate with fiber, vitamins, and controlled starch.',
        ];
    }

    private function mealInsightForSlug(string $slug, string $goal): ?string
    {
        $tips = [
            'jollof' => 'Jollof is a celebration dish—enjoy it with protein on the side and watch oily extras if weight loss is your goal.',
            'banku' => 'Banku fills you quickly. One serving with grilled tilapia and pepper is a balanced Ghanaian plate.',
            'fufu' => 'Fufu with light soup is satisfying—keep the soup lean and the fufu portion to about one medium ball.',
            'kenkey' => 'Kenkey pairs well with fried fish; swap occasional frying for grilled fish to cut extra fat.',
            'waakye' => 'Waakye gives lasting energy from beans and rice—add egg or fish so protein keeps you full longer.',
            'kelewele' => 'Kelewele is best as a side. A small portion with a protein main avoids an all-carb meal.',
            'plantain' => 'Ripe plantain is energy-rich. Boiled or grilled versions are gentler than large fried portions daily.',
            'beans' => 'Beans and gobe are excellent fiber and plant protein—ideal for steady blood sugar.',
            'rice' => 'Plain rice is a blank canvas—always add vegetables and a palm-sized protein portion.',
            'yam' => 'Yam is nutritious starch; pair with kontomire or garden egg stew for micronutrients.',
            'kokonte' => 'Kokonte is lighter than fufu for some—still mind portion size with soup.',
            'koose' => 'Koose is fried—balance with Hausa koko or fruit rather than another heavy starch.',
            'hausa-koko' => 'Hausa koko is a gentle breakfast—add groundnuts or egg if you need more protein.',
            'chicken' => "Chicken is lean protein—remove skin if you're reducing fat intake.",
            'meat' => 'Goat or beef stew is iron-rich; trim visible fat and pair with vegetables.',
            'egg-pepper' => 'Eggs are a quick protein win—great after a low-protein morning.',
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

    private function genericMealInsight(
        string $display,
        int $calories,
        string $goal,
        int $remainingKcal,
        int $proteinGap,
    ): string {
        if ($calories >= 700) {
            return "$display is a hearty meal. Drink water and make your next plate lighter on starch.";
        }
        if ($proteinGap > 25) {
            return "Good choice logging $display. Your day still needs more protein—add fish, beans, or eggs next.";
        }
        if ($goal === 'Lose weight' && $remainingKcal < 0) {
            return "$display logged. You're above target today—a short walk and a vegetable-heavy next meal will help.";
        }

        return "Nice work logging $display. Consistent tracking is how we fine-tune your Ghanaian meal plan.";
    }

    private function pairingSuggestion(string $slug): ?string
    {
        return match (true) {
            str_contains($slug, 'banku') => 'Pair with grilled tilapia and fresh pepper—not extra fried sides.',
            str_contains($slug, 'fufu') => 'Light soup with kontomire or garden eggs boosts vitamins.',
            str_contains($slug, 'jollof') => 'Add salad or coleslaw and grilled chicken for balance.',
            str_contains($slug, 'waakye') => 'Boiled egg, spaghetti portion control, and shito on the side only.',
            str_contains($slug, 'kenkey') => 'Grilled fish beats fried fish most days of the week.',
            str_contains($slug, 'rice') && ! str_contains($slug, 'jollof') => 'Stew with kontomire or salad—half plate vegetables.',
            default => null,
        };
    }

    private function portionNote(string $slug, int $calories): ?string
    {
        if ($calories >= 800) {
            return 'This looks like a large portion—next time, try serving starch and protein separately to control size.';
        }
        if (str_contains($slug, 'fufu') || str_contains($slug, 'banku')) {
            return 'One medium ball of starch is a standard dietitian portion for most adults.';
        }

        return null;
    }
}
