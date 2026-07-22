<?php

namespace App\Models;

use App\Support\MealCopy;
use Illuminate\Database\Eloquent\Model;

class FoodNutritionItem extends Model
{
    protected $fillable = [
        'class_name',
        'preparation_type',
        'display_name',
        'calories',
        'protein_g',
        'carbs_g',
        'fat_g',
        'iron_mg',
        'folate_mcg',
        'safety_status',
        'insight_message',
        'portion_label',
    ];

    protected function casts(): array
    {
        return [
            'iron_mg' => 'float',
        ];
    }

    public function toApiArray(): array
    {
        return [
            'className' => $this->class_name,
            'preparationType' => $this->preparation_type,
            'displayName' => MealCopy::friendlyName($this->display_name),
            'calories' => (int) $this->calories,
            'proteinG' => (int) $this->protein_g,
            'carbsG' => (int) $this->carbs_g,
            'fatG' => (int) $this->fat_g,
            'ironMg' => (float) $this->iron_mg,
            'folateMcg' => (int) $this->folate_mcg,
            'safetyStatus' => $this->safety_status,
            'insightMessage' => MealCopy::friendlyInsight($this->insight_message),
            'portionLabel' => $this->portion_label,
        ];
    }
}
