<?php

namespace App\Http\Controllers;

use App\Models\DailyStepLog;
use App\Models\MealLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;

class DashboardController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = auth()->user();

        // Prefer the device's calendar day so steps/meals match what "today" means on the phone.
        $localDateParam = $request->query('local_date');
        if (is_string($localDateParam) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $localDateParam)) {
            try {
                $stepDate = Carbon::createFromFormat('Y-m-d', $localDateParam)->toDateString();
            } catch (\Throwable) {
                $stepDate = now()->toDateString();
            }
        } else {
            $stepDate = now()->toDateString();
        }

        $mealsFrom = $request->query('meals_from');
        $mealsTo = $request->query('meals_to');
        $mealStart = null;
        $mealEndExcl = null;
        if (is_string($mealsFrom) && $mealsFrom !== '' && is_string($mealsTo) && $mealsTo !== '') {
            try {
                $mealStart = Carbon::parse($mealsFrom);
                $mealEndExcl = Carbon::parse($mealsTo);
            } catch (\Throwable) {
                $mealStart = null;
                $mealEndExcl = null;
            }
        }

        $anchorEnd = Carbon::createFromFormat('Y-m-d', $stepDate)->endOfDay();
        $start7 = $anchorEnd->copy()->subDays(6)->startOfDay();
        $end7 = $anchorEnd->copy();

        $gender = strtolower((string) ($user->gender ?? ''));
        $fallbackAvatar = match ($gender) {
            'male' => 'https://i.pravatar.cc/150?img=12',
            'female' => 'https://i.pravatar.cc/150?img=47',
            default => 'https://i.pravatar.cc/150?img=5',
        };
        $avatarUrl = (string) ($user->avatar_url ?: $fallbackAvatar);

        $todaySteps = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $stepDate)
            ->value('step_count') ?? 0;

        $activityLevel = (string) ($user->activity_level ?? '');
        $weightKg = is_numeric($user->weight) ? (float) $user->weight : null;
        $heightCm = is_numeric($user->height) ? (float) $user->height : null;
        $age = is_numeric($user->age) ? (int) $user->age : null;

        $goal = (string) ($user->goal ?? '');
        $workoutTimePreference = (string) ($user->workout_time_preference ?? '');
        $workoutDaysPerWeek = is_numeric($user->workout_days_per_week) ? (int) $user->workout_days_per_week : null;

        $stepGoal = $this->stepGoalFor($activityLevel, $goal);
        if (is_numeric($user->step_goal) && (int) $user->step_goal > 0) {
            $stepGoal = (int) $user->step_goal;
        }

        // Very rough burned estimate (until workouts/meals are fully logged).
        $burnedKcal = (int) round($todaySteps * 0.04);

        // Nutrition targets computed from the saved health profile.
        $targets = $this->nutritionTargets(
            gender: (string) ($user->gender ?? ''),
            age: $age,
            heightCm: $heightCm,
            weightKg: $weightKg,
            activityLevel: $activityLevel,
            goal: $goal
        );

        if (is_numeric($user->daily_calories_target) && (int) $user->daily_calories_target > 0) {
            $targets = $this->macroGramsForCalorieBudget(
                (int) $user->daily_calories_target,
                $weightKg,
                $goal
            );
        }

        $consumedKcal = 0;
        $consumedProteinG = 0;
        $consumedCarbsG = 0;
        $consumedFatG = 0;
        $mealsLoggedToday = 0;
        $mealsLogged7Days = 0;
        if (Schema::hasTable('meal_logs')) {
            $todayMealsQuery = MealLog::query()->where('user_id', $user->id);
            if ($mealStart !== null && $mealEndExcl !== null && $mealEndExcl->gt($mealStart)) {
                $todayMealsQuery
                    ->where('eaten_at', '>=', $mealStart)
                    ->where('eaten_at', '<', $mealEndExcl);
            } else {
                $todayMealsQuery->whereDate('eaten_at', $stepDate);
            }

            $consumedKcal = (int) (clone $todayMealsQuery)->sum('calories');
            $consumedProteinG = (int) (clone $todayMealsQuery)->sum(DB::raw('COALESCE(protein_g, 0)'));
            $consumedCarbsG = (int) (clone $todayMealsQuery)->sum(DB::raw('COALESCE(carbs_g, 0)'));
            $consumedFatG = (int) (clone $todayMealsQuery)->sum(DB::raw('COALESCE(fat_g, 0)'));

            $mealsLoggedToday = (int) (clone $todayMealsQuery)->count();

            $mealsLogged7Days = (int) MealLog::query()
                ->where('user_id', $user->id)
                ->whereBetween('eaten_at', [$start7, $end7])
                ->count();
        }

        $macrosEstimated = false;
        $macroKcalFromGrams = ($consumedProteinG * 4) + ($consumedCarbsG * 4) + ($consumedFatG * 9);
        if ($consumedKcal > 0 && $macroKcalFromGrams <= 0) {
            $estimated = $this->estimateMacrosGramsFromConsumedAndTargets($consumedKcal, $targets);
            $consumedProteinG = $estimated['proteinG'];
            $consumedCarbsG = $estimated['carbsG'];
            $consumedFatG = $estimated['fatG'];
            $macrosEstimated = true;
        } elseif ($consumedKcal > 0 && $macroKcalFromGrams > 0 && $macroKcalFromGrams < $consumedKcal) {
            // Some meals have calories but missing macros — scale today's gram totals so P/C/F kcal matches eaten kcal.
            $aligned = $this->alignMacroGramsToKcal($consumedKcal, $consumedProteinG, $consumedCarbsG, $consumedFatG);
            $consumedProteinG = $aligned['proteinG'];
            $consumedCarbsG = $aligned['carbsG'];
            $consumedFatG = $aligned['fatG'];
            $macrosEstimated = true;
        }

        $netKcal = $consumedKcal - $burnedKcal;

        [$tempCelsius, $locationLabel, $air] = $this->weatherAndAirQuality();

        [$alertTitle, $alertMessage] = $this->buildEnvironmentalAlert(
            tempCelsius: $tempCelsius,
            airQualityAqi: $air['aqi'] ?? null,
            pm25: $air['pm2_5'] ?? null,
            pm10: $air['pm10'] ?? null,
            weatherMain: $air['weatherMain'] ?? null,
            weatherDescription: $air['weatherDescription'] ?? null,
        );

        return response()->json([
            'userName' => $user->name,
            'avatarUrl' => $avatarUrl,
            'goal' => $goal ?: null,
            'netKcal' => $netKcal,
            'consumedKcal' => $consumedKcal,
            'burnedKcal' => $burnedKcal,
            'tempCelsius' => $tempCelsius,
            'location' => $locationLabel,
            'alertTitle' => $alertTitle,
            'alertMessage' => $alertMessage,
            'currentSteps' => $todaySteps,
            'stepGoal' => $stepGoal,
            'weather' => [
                'main' => $air['weatherMain'] ?? null,
                'description' => $air['weatherDescription'] ?? null,
            ],
            'airQuality' => [
                'aqi' => $air['aqi'] ?? null,
                'pm2_5' => $air['pm2_5'] ?? null,
                'pm10' => $air['pm10'] ?? null,
            ],
            'dailyCaloriesTarget' => $targets['dailyCaloriesTarget'],
            // Today's logged / scanned meals (same window as consumedKcal).
            'macros' => [
                'proteinG' => $consumedProteinG,
                'carbsG' => $consumedCarbsG,
                'fatG' => $consumedFatG,
            ],
            // Profile/calorie-goal targets (for comparisons & coaching copy).
            'macrosTarget' => [
                'proteinG' => $targets['proteinG'],
                'carbsG' => $targets['carbsG'],
                'fatG' => $targets['fatG'],
            ],
            // True when grams were inferred and/or scaled so macro calories match eaten kcal for today.
            'macrosEstimated' => $macrosEstimated,
            'workoutPlan' => [
                'preferredTime' => $workoutTimePreference ?: null,
                'daysPerWeek' => $workoutDaysPerWeek,
                'suggested' => $this->suggestWorkoutPlan($workoutDaysPerWeek, $workoutTimePreference),
            ],
            'mealsLoggedToday' => $mealsLoggedToday,
            'mealsLogged7Days' => $mealsLogged7Days,
            'calories' => max(0, $netKcal),
            'activeMinutes' => (int) round($todaySteps / 120),
        ]);
    }

    /**
     * Scale protein/carbs/fat so 4P+4C+9F equals targetKcal (same shape as logged totals).
     *
     * @return array{proteinG: int, carbsG: int, fatG: int}
     */
    private function alignMacroGramsToKcal(int $targetKcal, int $p, int $c, int $f): array
    {
        if ($targetKcal <= 0) {
            return ['proteinG' => 0, 'carbsG' => 0, 'fatG' => 0];
        }

        $mkcal = ($p * 4) + ($c * 4) + ($f * 9);
        if ($mkcal <= 0) {
            return ['proteinG' => 0, 'carbsG' => 0, 'fatG' => 0];
        }

        $scale = $targetKcal / $mkcal;
        $baseP = max(0, (int) round($p * $scale));
        $baseC = max(0, (int) round($c * $scale));
        $baseF = max(0, (int) round($f * $scale));

        $best = ['proteinG' => $baseP, 'carbsG' => $baseC, 'fatG' => $baseF];
        $bestDist = abs($targetKcal - (($baseP * 4) + ($baseC * 4) + ($baseF * 9)));

        for ($dp = -12; $dp <= 12; $dp++) {
            for ($dc = -12; $dc <= 12; $dc++) {
                $tp = max(0, $baseP + $dp);
                $tc = max(0, $baseC + $dc);
                $afterPc = ($tp * 4) + ($tc * 4);
                if ($afterPc > $targetKcal) {
                    continue;
                }
                $rem = $targetKcal - $afterPc;
                $tfApprox = (int) round($rem / 9);
                foreach ([$tfApprox - 1, $tfApprox, $tfApprox + 1] as $tf) {
                    if ($tf < 0) {
                        continue;
                    }
                    $got = $afterPc + ($tf * 9);
                    $dist = abs($targetKcal - $got);
                    if ($dist < $bestDist) {
                        $bestDist = $dist;
                        $best = ['proteinG' => $tp, 'carbsG' => $tc, 'fatG' => $tf];
                    }
                    if ($bestDist === 0) {
                        break 3;
                    }
                }
            }
        }

        return $best;
    }

    /**
     * Spread today's consumed calories across macros using the same proportions as
     * the user's daily macro targets (calorie goal split).
     *
     * @param  array{dailyCaloriesTarget: int, proteinG: int, carbsG: int, fatG: int}  $targets
     * @return array{proteinG: int, carbsG: int, fatG: int}
     */
    private function estimateMacrosGramsFromConsumedAndTargets(int $consumedKcal, array $targets): array
    {
        $daily = (int) ($targets['dailyCaloriesTarget'] ?? 0);
        $tp = (int) ($targets['proteinG'] ?? 0);
        $tc = (int) ($targets['carbsG'] ?? 0);
        $tf = (int) ($targets['fatG'] ?? 0);

        if ($daily > 0 && ($tp + $tc + $tf) > 0) {
            $ratio = max(0.0, $consumedKcal / $daily);

            return [
                'proteinG' => max(0, (int) round($tp * $ratio)),
                'carbsG' => max(0, (int) round($tc * $ratio)),
                'fatG' => max(0, (int) round($tf * $ratio)),
            ];
        }

        return [
            'proteinG' => max(0, (int) round($consumedKcal * 0.25 / 4)),
            'carbsG' => max(0, (int) round($consumedKcal * 0.50 / 4)),
            'fatG' => max(0, (int) round($consumedKcal * 0.25 / 9)),
        ];
    }

    private function weatherAndAirQuality(): array
    {
        $apiKey = trim((string) config('services.openweather.key', ''));
        $lat = (float) config('services.openweather.default_lat', 5.6037);
        $lon = (float) config('services.openweather.default_lon', -0.1870);
        $fallbackLabel = (string) config('services.openweather.default_label', 'Accra, GH');

        if ($apiKey === '') {
            return [0.0, $fallbackLabel, []];
        }

        $cacheKey = "openweather:{$lat}:{$lon}";

        try {
            // Use file cache to avoid 500s when CACHE_STORE=database without cache tables.
            return Cache::store('file')->remember($cacheKey, now()->addMinutes(10), function () use ($apiKey, $lat, $lon, $fallbackLabel) {
                return $this->fetchOpenWeather($apiKey, $lat, $lon, $fallbackLabel);
            });
        } catch (\Throwable $e) {
            // Fail gracefully (never break the dashboard due to weather).
            try {
                return $this->fetchOpenWeather($apiKey, $lat, $lon, $fallbackLabel);
            } catch (\Throwable $e2) {
                return [0.0, $fallbackLabel, []];
            }
        }
    }

    private function fetchOpenWeather(string $apiKey, float $lat, float $lon, string $fallbackLabel): array
    {
        $weather = Http::timeout(6)->get('https://api.openweathermap.org/data/2.5/weather', [
            'lat' => $lat,
            'lon' => $lon,
            'appid' => $apiKey,
            'units' => 'metric',
        ]);

        $air = Http::timeout(6)->get('https://api.openweathermap.org/data/2.5/air_pollution', [
            'lat' => $lat,
            'lon' => $lon,
            'appid' => $apiKey,
        ]);

        $temp = 0.0;
        $label = $fallbackLabel;
        $weatherMain = null;
        $weatherDesc = null;

        if ($weather->ok()) {
            $temp = (float) data_get($weather->json(), 'main.temp', 0.0);
            $name = (string) data_get($weather->json(), 'name', '');
            $country = (string) data_get($weather->json(), 'sys.country', '');
            $label = trim($name.(strlen($country) ? ", {$country}" : '')) ?: $fallbackLabel;
            $weatherMain = data_get($weather->json(), 'weather.0.main');
            $weatherDesc = data_get($weather->json(), 'weather.0.description');
        }

        $aqi = null;
        $pm25 = null;
        $pm10 = null;
        if ($air->ok()) {
            $aqi = data_get($air->json(), 'list.0.main.aqi');
            $pm25 = data_get($air->json(), 'list.0.components.pm2_5');
            $pm10 = data_get($air->json(), 'list.0.components.pm10');
        }

        return [
            $temp,
            $label,
            [
                'aqi' => is_numeric($aqi) ? (int) $aqi : null, // 1..5
                'pm2_5' => is_numeric($pm25) ? round((float) $pm25, 1) : null,
                'pm10' => is_numeric($pm10) ? round((float) $pm10, 1) : null,
                'weatherMain' => $weatherMain ? (string) $weatherMain : null,
                'weatherDescription' => $weatherDesc ? (string) $weatherDesc : null,
            ],
        ];
    }

    private function buildEnvironmentalAlert(
        float $tempCelsius,
        ?int $airQualityAqi,
        $pm25,
        $pm10,
        ?string $weatherMain,
        ?string $weatherDescription,
    ): array {
        $isHighHeat = $tempCelsius >= 32.0;
        $isPoorAir = $airQualityAqi !== null && $airQualityAqi >= 4; // 4/5 = poor/very poor
        $desc = strtolower((string) ($weatherDescription ?? ''));
        $isDusty = str_contains($desc, 'dust') || str_contains($desc, 'sand') || str_contains($desc, 'haze');

        if ($isPoorAir || $isDusty) {
            $pmText = [];
            if (is_numeric($pm25)) {
                $pmText[] = 'PM2.5 '.round((float) $pm25).'µg/m³';
            }
            if (is_numeric($pm10)) {
                $pmText[] = 'PM10 '.round((float) $pm10).'µg/m³';
            }
            $extra = count($pmText) ? (' ('.implode(', ', $pmText).')') : '';

            return [
                'Harmattan / Air Quality Alert',
                'Air quality is poor today'.$extra.'. Limit intense outdoor workouts, keep workouts lighter today, and consider a mask if sensitive.',
            ];
        }

        if ($isHighHeat) {
            return [
                'High Heat Advisory',
                'It’s hot today. Prefer shade, rest breaks, and lower-intensity movement.',
            ];
        }

        return [
            'No Alerts',
            'All clear. Keep moving steadily today.',
        ];
    }

    private function stepGoalFor(string $activityLevel, string $goal): int
    {
        $base = match ($activityLevel) {
            'Sedentary' => 6000,
            'Lightly active' => 8000,
            'Moderately active' => 10000,
            'Very active' => 12000,
            'Extremely active' => 14000,
            default => 10000,
        };

        return match ($goal) {
            'Lose weight' => (int) round($base * 1.05),
            'Gain weight' => (int) round($base * 0.95),
            default => $base,
        };
    }

    /**
     * Returns nutrition targets.
     * - dailyCaloriesTarget (kcal)
     * - proteinG / carbsG / fatG (grams)
     */
    private function nutritionTargets(
        string $gender,
        ?int $age,
        ?float $heightCm,
        ?float $weightKg,
        string $activityLevel,
        string $goal
    ): array {
        // Defaults if profile isn't complete yet.
        $age ??= 30;
        $heightCm ??= 170.0;
        $weightKg ??= 70.0;

        $genderKey = strtolower(trim($gender));
        $bmr = match ($genderKey) {
            'male' => (10 * $weightKg) + (6.25 * $heightCm) - (5 * $age) + 5,
            'female' => (10 * $weightKg) + (6.25 * $heightCm) - (5 * $age) - 161,
            default => (10 * $weightKg) + (6.25 * $heightCm) - (5 * $age) - 78,
        };

        $multiplier = match ($activityLevel) {
            'Sedentary' => 1.2,
            'Lightly active' => 1.375,
            'Moderately active' => 1.55,
            'Very active' => 1.725,
            'Extremely active' => 1.9,
            default => 1.55,
        };

        $maintenance = $bmr * $multiplier;
        $dailyCaloriesTarget = match ($goal) {
            'Lose weight' => (int) round(max(1200, $maintenance - 500)),
            'Gain weight' => (int) round($maintenance + 300),
            default => (int) round($maintenance),
        };

        return $this->macroGramsForCalorieBudget($dailyCaloriesTarget, $weightKg, $goal);
    }

    /**
     * @return array{dailyCaloriesTarget: int, proteinG: int, carbsG: int, fatG: int}
     */
    private function macroGramsForCalorieBudget(int $dailyCaloriesTarget, ?float $weightKg, string $goal): array
    {
        $weightKg ??= 70.0;

        $proteinPerKg = match ($goal) {
            'Lose weight' => 1.8,
            'Gain weight' => 1.6,
            default => 1.4,
        };
        $proteinG = (int) round($weightKg * $proteinPerKg);
        $fatG = (int) round($weightKg * 0.8);

        $proteinKcal = $proteinG * 4;
        $fatKcal = $fatG * 9;
        $carbKcal = max(0, $dailyCaloriesTarget - $proteinKcal - $fatKcal);
        $carbsG = (int) floor($carbKcal / 4);

        return [
            'dailyCaloriesTarget' => $dailyCaloriesTarget,
            'proteinG' => $proteinG,
            'carbsG' => $carbsG,
            'fatG' => $fatG,
        ];
    }

    private function suggestWorkoutPlan(?int $daysPerWeek, string $preferredTime): array
    {
        $daysPerWeek ??= 3;
        $daysPerWeek = max(1, min(7, $daysPerWeek));

        $timeLabel = match ($preferredTime) {
            'Morning' => 'Morning',
            'Evening' => 'Evening',
            'Flexible' => 'Flexible',
            default => 'Flexible',
        };

        // Simple suggested schedule (UI-friendly).
        $week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        $indices = match ($daysPerWeek) {
            1 => [2],
            2 => [1, 4],
            3 => [0, 2, 4],
            4 => [0, 2, 4, 6],
            5 => [0, 1, 3, 4, 6],
            6 => [0, 1, 2, 4, 5, 6],
            default => [0, 1, 2, 3, 4, 5, 6],
        };

        return array_map(
            fn ($i) => [
                'day' => $week[$i],
                'time' => $timeLabel,
                'focus' => 'Walk + Mobility',
            ],
            $indices
        );
    }
}
