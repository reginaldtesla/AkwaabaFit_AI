<?php

namespace Database\Seeders;

use App\Models\FoodNutritionItem;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;

class FoodNutritionItemSeeder extends Seeder
{
    public function run(): void
    {
        $path = database_path('data/food_nutrition_defaults.json');
        if (! File::exists($path)) {
            return;
        }

        $rows = json_decode(File::get($path), true);
        if (! is_array($rows)) {
            return;
        }

        foreach ($rows as $row) {
            FoodNutritionItem::updateOrCreate(
                ['class_name' => $row['class_name']],
                [
                    'display_name' => $row['display_name'],
                    'calories' => (int) ($row['calories'] ?? 0),
                    'protein_g' => (int) ($row['protein_g'] ?? 0),
                    'carbs_g' => (int) ($row['carbs_g'] ?? 0),
                    'fat_g' => (int) ($row['fat_g'] ?? 0),
                    'iron_mg' => (float) ($row['iron_mg'] ?? 0),
                    'folate_mcg' => (int) ($row['folate_mcg'] ?? 0),
                    'safety_status' => $row['safety_status'] ?? 'safe',
                    'insight_message' => $row['insight_message'] ?? null,
                    'portion_label' => $row['portion_label'] ?? '1 serving',
                ],
            );
        }
    }
}
