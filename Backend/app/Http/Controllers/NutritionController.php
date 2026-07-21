<?php

namespace App\Http\Controllers;

use App\Models\FoodNutritionItem;
use App\Models\MealLog;
use App\Models\User;
use App\Services\DietitianAdviceService;
use App\Services\FoodScanService;
use App\Support\HealthProfileOptions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Throwable;

class NutritionController extends Controller
{
    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $from = $request->query('from');
        $to = $request->query('to');

        $fromDate = $from ? Carbon::parse($from)->startOfDay() : now()->subDays(14)->startOfDay();
        $toDate = $to ? Carbon::parse($to)->endOfDay() : now()->endOfDay();

        $logs = MealLog::query()
            ->where('user_id', $user->id)
            ->whereBetween('eaten_at', [$fromDate, $toDate])
            ->orderByDesc('eaten_at')
            ->get();

        $grouped = $logs->groupBy(fn (MealLog $m) => $m->eaten_at->toDateString())
            ->map(function ($items, $date) {
                $totalKcal = (int) $items->sum('calories');

                return [
                    'date' => $date,
                    'totalKcal' => $totalKcal,
                    'meals' => $items->values()->map(function (MealLog $m) {
                        return [
                            'id' => (string) $m->id,
                            'name' => $m->name,
                            'eatenAt' => $m->eaten_at->toIso8601String(),
                            'mealType' => $m->meal_type,
                            'calories' => (int) $m->calories,
                            'proteinG' => $m->protein_g,
                            'carbsG' => $m->carbs_g,
                            'fatG' => $m->fat_g,
                            'safetyStatus' => $m->safety_status,
                            'insightMessage' => $m->insight_message,
                            'imageUrl' => $m->image_url,
                            'source' => $m->source,
                            'portionSize' => $m->portion_size,
                            'mealSource' => $m->meal_source,
                            'meta' => $m->meta,
                        ];
                    }),
                ];
            })
            ->values();

        return response()->json([
            'status' => 'success',
            'from' => $fromDate->toDateString(),
            'to' => $toDate->toDateString(),
            'days' => $grouped,
        ]);
    }

    /**
     * Nutrition lookup for a detected food class (hybrid mobile: refresh when online).
     */
    public function food(Request $request): JsonResponse
    {
        $className = Str::lower(trim((string) ($request->query('class_name') ?? $request->query('class') ?? '')));
        if ($className === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'class_name is required',
            ], 422);
        }

        $item = FoodNutritionItem::query()->where('class_name', $className)->first();
        if (! $item) {
            return response()->json([
                'status' => 'not_found',
                'message' => 'No nutrition profile for this food class',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'source' => 'server',
            'food' => $item->toApiArray(),
        ]);
    }

    /**
     * Full catalog for offline cache refresh on the device.
     */
    public function foods(): JsonResponse
    {
        $items = FoodNutritionItem::query()
            ->orderBy('class_name')
            ->get()
            ->map(fn (FoodNutritionItem $item) => $item->toApiArray())
            ->values();

        return response()->json([
            'status' => 'success',
            'source' => 'server',
            'updatedAt' => now()->toIso8601String(),
            'foods' => $items,
        ]);
    }

    /**
     * Search food catalog (manual logging).
     */
    public function searchFoods(Request $request): JsonResponse
    {
        $q = Str::lower(trim((string) $request->query('q', '')));
        $prep = trim((string) $request->query('preparation', ''));

        $query = FoodNutritionItem::query()->orderBy('display_name');
        if ($q !== '') {
            $query->where(function ($builder) use ($q) {
                $builder->where('class_name', 'like', "%{$q}%")
                    ->orWhere('display_name', 'like', "%{$q}%");
            });
        }
        if ($prep !== '') {
            $query->where('preparation_type', $prep);
        }

        $items = $query->limit(30)->get()->map(fn (FoodNutritionItem $item) => $item->toApiArray());

        return response()->json([
            'status' => 'success',
            'foods' => $items,
        ]);
    }

    /**
     * Recent meals for quick re-log.
     */
    public function recentMeals(Request $request): JsonResponse
    {
        $user = $request->user();
        $logs = MealLog::query()
            ->where('user_id', $user->id)
            ->orderByDesc('eaten_at')
            ->limit(20)
            ->get();

        $unique = $logs->unique(fn (MealLog $m) => Str::lower($m->name))->take(8)->values();

        return response()->json([
            'status' => 'success',
            'meals' => $unique->map(fn (MealLog $m) => [
                'name' => $m->name,
                'calories' => (int) $m->calories,
                'proteinG' => $m->protein_g,
                'carbsG' => $m->carbs_g,
                'fatG' => $m->fat_g,
                'mealType' => $m->meal_type,
                'portionSize' => $m->portion_size,
                'mealSource' => $m->meal_source,
                'meta' => $m->meta,
            ]),
        ]);
    }

    public function scan(Request $request, FoodScanService $scanner): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,webp', 'max:10240'],
        ]);

        try {
            $result = $scanner->scan($request->file('image'));
        } catch (Throwable $e) {
            report($e);

            return response()->json([
                'status' => 'error',
                'not_food' => false,
                'provider' => 'hybrid',
                'strategy' => 'error',
                'detections' => [],
                'message' => 'Scan service failed. Check your connection and try again.',
            ], 503);
        }

        if ($result['detections'] === []) {
            return response()->json([
                'status' => 'success',
                'not_food' => true,
                'provider' => $result['provider'],
                'strategy' => $result['strategy'],
                'detections' => [],
                'message' => "We couldn't identify the food. Try a brighter photo with the whole plate in frame, or log the meal manually.",
            ]);
        }

        return response()->json([
            'status' => 'success',
            'provider' => $result['provider'],
            'strategy' => $result['strategy'],
            'detections' => $result['detections'],
        ]);
    }

    public function log(Request $request, DietitianAdviceService $dietitian): JsonResponse
    {
        $user = $request->user();

        // Mobile / JSON clients may send camelCase macro keys.
        if ($request->has('proteinG') && ! $request->has('protein_g')) {
            $request->merge(['protein_g' => $request->input('proteinG')]);
        }
        if ($request->has('carbsG') && ! $request->has('carbs_g')) {
            $request->merge(['carbs_g' => $request->input('carbsG')]);
        }
        if ($request->has('fatG') && ! $request->has('fat_g')) {
            $request->merge(['fat_g' => $request->input('fatG')]);
        }

        $data = $request->validate([
            'eaten_at' => ['nullable', 'date'],
            'meal_type' => ['nullable', 'string', 'max:50'],
            'name' => ['required', 'string', 'max:255'],
            'calories' => ['nullable', 'integer', 'min:0', 'max:5000'],
            'protein_g' => ['nullable', 'integer', 'min:0', 'max:500'],
            'carbs_g' => ['nullable', 'integer', 'min:0', 'max:800'],
            'fat_g' => ['nullable', 'integer', 'min:0', 'max:300'],
            'safety_status' => ['nullable', 'string', 'max:50'],
            'insight_message' => ['nullable', 'string', 'max:255'],
            'image_url' => ['nullable', 'string', 'max:1000'],
            'source' => ['nullable', 'string', 'in:scan,manual'],
            'portion_size' => ['nullable', 'string', Rule::in(HealthProfileOptions::portionSizes())],
            'meal_source' => ['nullable', 'string', Rule::in(HealthProfileOptions::mealSources())],
            'meta' => ['nullable', 'array'],
        ]);

        $multiplier = HealthProfileOptions::portionMultiplier($data['portion_size'] ?? null);
        if ($multiplier !== 1.0) {
            foreach (['calories', 'protein_g', 'carbs_g', 'fat_g'] as $field) {
                if (isset($data[$field])) {
                    $data[$field] = (int) round($data[$field] * $multiplier);
                }
            }
        }

        $insight = $data['insight_message'] ?? null;
        if (! is_string($insight) || trim($insight) === '') {
            $className = null;
            $meta = $data['meta'] ?? null;
            if (is_array($meta)) {
                $className = $meta['class_name'] ?? $meta['className'] ?? null;
            }
            $gaps = $this->todayNutritionGaps($user);
            $mealAdvice = $dietitian->mealAdvice(
                foodName: $data['name'],
                className: is_string($className) ? $className : null,
                calories: (int) ($data['calories'] ?? 0),
                proteinG: (int) ($data['protein_g'] ?? 0),
                carbsG: (int) ($data['carbs_g'] ?? 0),
                fatG: (int) ($data['fat_g'] ?? 0),
                goal: (string) ($user->goal ?? ''),
                remainingKcal: $gaps['remaining_kcal'],
                proteinGap: $gaps['protein_gap'],
                user: $user,
            );
            $insight = $mealAdvice['insight'];
        }

        $meal = MealLog::create([
            'user_id' => $user->id,
            'eaten_at' => isset($data['eaten_at']) ? Carbon::parse($data['eaten_at']) : now(),
            'meal_type' => $data['meal_type'] ?? null,
            'name' => $data['name'],
            'calories' => (int) ($data['calories'] ?? 0),
            'protein_g' => $data['protein_g'] ?? null,
            'carbs_g' => $data['carbs_g'] ?? null,
            'fat_g' => $data['fat_g'] ?? null,
            'safety_status' => $data['safety_status'] ?? null,
            'insight_message' => $insight,
            'image_url' => $data['image_url'] ?? null,
            'source' => $data['source'] ?? 'scan',
            'portion_size' => $data['portion_size'] ?? null,
            'meal_source' => $data['meal_source'] ?? null,
            'meta' => $data['meta'] ?? null,
        ]);

        return response()->json([
            'status' => 'success',
            'meal' => $meal,
        ], 201);
    }

    /**
     * Dietitian-style coaching for a meal before or after logging (mobile scan card).
     */
    public function mealAdvice(Request $request, DietitianAdviceService $dietitian): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'class_name' => ['nullable', 'string', 'max:120'],
            'calories' => ['nullable', 'integer', 'min:0', 'max:5000'],
            'protein_g' => ['nullable', 'integer', 'min:0', 'max:500'],
            'carbs_g' => ['nullable', 'integer', 'min:0', 'max:800'],
            'fat_g' => ['nullable', 'integer', 'min:0', 'max:300'],
        ]);

        $user = $request->user();
        $gaps = $this->todayNutritionGaps($user);
        $advice = $dietitian->mealAdvice(
            foodName: $data['name'],
            className: $data['class_name'] ?? null,
            calories: (int) ($data['calories'] ?? 0),
            proteinG: (int) ($data['protein_g'] ?? 0),
            carbsG: (int) ($data['carbs_g'] ?? 0),
            fatG: (int) ($data['fat_g'] ?? 0),
            goal: (string) ($user->goal ?? ''),
            remainingKcal: $gaps['remaining_kcal'],
            proteinGap: $gaps['protein_gap'],
            user: $user,
        );

        return response()->json([
            'status' => 'success',
            'advice' => $advice,
        ]);
    }

    /**
     * @return array{remaining_kcal: int, protein_gap: int}
     */
    private function todayNutritionGaps(User $user): array
    {
        $today = MealLog::query()
            ->where('user_id', $user->id)
            ->whereDate('eaten_at', today());

        $consumedKcal = (int) (clone $today)->sum('calories');
        $consumedProtein = (int) (clone $today)->sum(DB::raw('COALESCE(protein_g, 0)'));

        $targetKcal = is_numeric($user->daily_calories_target) ? (int) $user->daily_calories_target : 0;
        $targetProtein = is_numeric($user->weight) ? (int) round((float) $user->weight * 1.4) : 0;

        return [
            'remaining_kcal' => $targetKcal > 0 ? $targetKcal - $consumedKcal : 0,
            'protein_gap' => $targetProtein > 0 ? $targetProtein - $consumedProtein : 0,
        ];
    }
}
