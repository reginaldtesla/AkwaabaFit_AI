<?php

namespace App\Http\Controllers;

use App\Models\FoodNutritionItem;
use App\Models\MealLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

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

    public function log(Request $request): JsonResponse
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
            'meta' => ['nullable', 'array'],
        ]);

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
            'insight_message' => $data['insight_message'] ?? null,
            'image_url' => $data['image_url'] ?? null,
            'source' => $data['source'] ?? 'scan',
            'meta' => $data['meta'] ?? null,
        ]);

        return response()->json([
            'status' => 'success',
            'meal' => $meal,
        ], 201);
    }
}
