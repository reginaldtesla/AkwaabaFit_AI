<?php

namespace App\Support;

/**
 * Allowed health-assistant profile values for validation and mobile pickers.
 */
class HealthProfileOptions
{
  /** @return list<string> */
    public static function goals(): array
    {
        return ['Gain weight', 'Lose weight', 'Maintain weight'];
    }

    /** @return list<string> */
    public static function healthConditions(): array
    {
        return [
            'None',
            'High blood pressure',
            'Diabetes',
            'Anaemia',
            'Sickle cell',
            'High cholesterol',
        ];
    }

    /** @return list<string> */
    public static function eatingPatterns(): array
    {
        return [
            'Regular',
            'Ramadan',
            'Lent',
            'Church fast days',
            'Intermittent fasting',
        ];
    }

    /** @return list<string> */
    public static function lifeStages(): array
    {
        return [
            'General adult',
            'Pregnant',
            'Breastfeeding',
            'Caring for young child',
        ];
    }

    /** @return list<string> */
    public static function mealSourcePreferences(): array
    {
        return ['Chop bar', 'Home-cooked', 'Mixed'];
    }

    /** @return list<string> */
    public static function activityContexts(): array
    {
        return [
            'Office / desk',
            'Market & trotro',
            'Active job',
            'Student',
            'Mixed',
        ];
    }

    /** @return list<string> */
    public static function portionSizes(): array
    {
        return ['small', 'regular', 'large'];
    }

    /** @return list<string> */
    public static function mealSources(): array
    {
        return ['chop_bar', 'home_cooked'];
    }

    public static function portionMultiplier(?string $size): float
    {
        return match ($size) {
            'small' => 0.75,
            'large' => 1.35,
            default => 1.0,
        };
    }

    public static function defaultWaterGoalMl(?int $weightKg): int
    {
        $base = $weightKg && $weightKg > 0 ? (int) round($weightKg * 35) : 2000;

        return max(1500, min(4000, $base));
    }

    public static function ghanaStepGoalForContext(string $context, string $activityLevel): int
    {
        $base = match ($context) {
            'Market & trotro' => 12000,
            'Active job' => 11000,
            'Student' => 9000,
            'Office / desk' => 7500,
            default => 10000,
        };

        return match ($activityLevel) {
            'Sedentary' => (int) round($base * 0.85),
            'Very active', 'Extremely active' => (int) round($base * 1.15),
            default => $base,
        };
    }
}
