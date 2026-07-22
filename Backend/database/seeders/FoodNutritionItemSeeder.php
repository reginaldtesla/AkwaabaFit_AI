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
                [
                    'class_name' => $row['class_name'],
                    'preparation_type' => $row['preparation_type'] ?? 'standard',
                ],
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

        $variants = [
            ['class_name' => 'banku', 'preparation_type' => 'chop_bar', 'display_name' => 'Banku', 'calories' => 520, 'protein_g' => 8, 'carbs_g' => 98, 'fat_g' => 6],
            ['class_name' => 'banku', 'preparation_type' => 'home_cooked', 'display_name' => 'Banku (home)', 'calories' => 400, 'protein_g' => 7, 'carbs_g' => 82, 'fat_g' => 4],
            ['class_name' => 'jollof', 'preparation_type' => 'chop_bar', 'display_name' => 'Jollof', 'calories' => 580, 'protein_g' => 14, 'carbs_g' => 78, 'fat_g' => 22],
            ['class_name' => 'jollof', 'preparation_type' => 'home_cooked', 'display_name' => 'Jollof (home)', 'calories' => 480, 'protein_g' => 12, 'carbs_g' => 72, 'fat_g' => 14],
            ['class_name' => 'waakye', 'preparation_type' => 'chop_bar', 'display_name' => 'Waakye', 'calories' => 720, 'protein_g' => 22, 'carbs_g' => 95, 'fat_g' => 24],
            ['class_name' => 'waakye', 'preparation_type' => 'home_cooked', 'display_name' => 'Waakye (home)', 'calories' => 520, 'protein_g' => 16, 'carbs_g' => 78, 'fat_g' => 12],
            ['class_name' => 'kenkey', 'preparation_type' => 'chop_bar', 'display_name' => 'Kenkey & fish', 'calories' => 650, 'protein_g' => 28, 'carbs_g' => 88, 'fat_g' => 18],
            ['class_name' => 'kenkey', 'preparation_type' => 'home_cooked', 'display_name' => 'Kenkey (home)', 'calories' => 420, 'protein_g' => 12, 'carbs_g' => 76, 'fat_g' => 8],
        ];

        foreach ($variants as $row) {
            FoodNutritionItem::updateOrCreate(
                [
                    'class_name' => $row['class_name'],
                    'preparation_type' => $row['preparation_type'],
                ],
                [
                    'display_name' => $row['display_name'],
                    'calories' => $row['calories'],
                    'protein_g' => $row['protein_g'],
                    'carbs_g' => $row['carbs_g'],
                    'fat_g' => $row['fat_g'],
                    'iron_mg' => 0,
                    'folate_mcg' => 0,
                    'safety_status' => 'safe',
                    'portion_label' => '1 serving',
                ],
            );
        }
    }
}
