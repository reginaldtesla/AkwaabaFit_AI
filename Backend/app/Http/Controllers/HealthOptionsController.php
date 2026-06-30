<?php

namespace App\Http\Controllers;

use App\Support\HealthProfileOptions;
use Illuminate\Http\JsonResponse;

class HealthOptionsController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'options' => [
                'goals' => HealthProfileOptions::goals(),
                'healthConditions' => HealthProfileOptions::healthConditions(),
                'eatingPatterns' => HealthProfileOptions::eatingPatterns(),
                'lifeStages' => HealthProfileOptions::lifeStages(),
                'mealSourcePreferences' => HealthProfileOptions::mealSourcePreferences(),
                'activityContexts' => HealthProfileOptions::activityContexts(),
                'portionSizes' => HealthProfileOptions::portionSizes(),
                'mealSources' => HealthProfileOptions::mealSources(),
            ],
        ]);
    }
}
