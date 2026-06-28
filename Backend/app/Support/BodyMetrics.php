<?php

namespace App\Support;

/**
 * BMI and activity snapshot for dietitian coaching.
 */
class BodyMetrics
{
    public static function bmi(?float $weightKg, ?float $heightCm): ?float
    {
        if ($weightKg === null || $heightCm === null || $weightKg <= 0 || $heightCm <= 0) {
            return null;
        }

        $heightM = $heightCm / 100;

        return round($weightKg / ($heightM * $heightM), 1);
    }

    public static function category(?float $bmi): ?string
    {
        if ($bmi === null) {
            return null;
        }

        return match (true) {
            $bmi < 18.5 => 'Underweight',
            $bmi < 25 => 'Normal weight',
            $bmi < 30 => 'Overweight',
            default => 'Obese',
        };
    }

    /**
     * @return array{
     *   weightKg: float|null,
     *   heightCm: float|null,
     *   bmi: float|null,
     *   bmiCategory: string|null,
     *   goal: string|null,
     *   todaySteps: int,
     *   stepGoal: int,
     *   burnedKcal: int,
     *   consumedKcal: int,
     *   netKcal: int,
     *   dailyCaloriesTarget: int,
     *   netRemainingKcal: int|null
     * }
     */
    public static function snapshot(
        ?float $weightKg,
        ?float $heightCm,
        string $goal,
        int $todaySteps,
        int $stepGoal,
        int $burnedKcal,
        int $consumedKcal,
        int $dailyCaloriesTarget,
    ): array {
        $bmi = self::bmi($weightKg, $heightCm);
        $netKcal = max(0, $consumedKcal - $burnedKcal);
        $netRemaining = $dailyCaloriesTarget > 0 ? $dailyCaloriesTarget - $netKcal : null;

        return [
            'weightKg' => $weightKg,
            'heightCm' => $heightCm,
            'bmi' => $bmi,
            'bmiCategory' => self::category($bmi),
            'goal' => $goal !== '' ? $goal : null,
            'todaySteps' => max(0, $todaySteps),
            'stepGoal' => max(0, $stepGoal),
            'burnedKcal' => max(0, $burnedKcal),
            'consumedKcal' => max(0, $consumedKcal),
            'netKcal' => $netKcal,
            'dailyCaloriesTarget' => max(0, $dailyCaloriesTarget),
            'netRemainingKcal' => $netRemaining,
        ];
    }

    public static function portionHint(?float $bmi, string $goal): string
    {
        $category = self::category($bmi);

        if ($goal === 'Lose weight' || $category === 'Overweight' || $category === 'Obese') {
            return 'Palm-sized fish or meat, one ball of banku/fufu/kenkey, and extra kontomire or salad on the side.';
        }

        if ($goal === 'Gain weight' || $category === 'Underweight') {
            return 'Full chop bar portions are fine—add groundnut soup, egg, or fish so calories and protein climb steadily.';
        }

        return 'Palm-sized protein, one ball of swallow, and soup or stew to balance the plate.';
    }

    public static function bmiCoachingLine(?float $bmi, string $goal): ?string
    {
        $category = self::category($bmi);
        if ($category === null) {
            return null;
        }

        return match (true) {
            $goal === 'Lose weight' && in_array($category, ['Overweight', 'Obese'], true) =>
                "Your BMI is in the {$category} range—pair your goal with smaller starch portions and more grilled fish or beans.",
            $goal === 'Gain weight' && $category === 'Underweight' =>
                'Your BMI is underweight—regular meals plus groundnut snacks and protein-rich chops support healthy gain.',
            $category === 'Normal weight' =>
                'Your BMI is in a healthy range—keep steady portions and stay active.',
            $goal === 'Lose weight' =>
                "BMI category: {$category}. Focus on lean protein, kontomire, and fewer fried sides.",
            default => "BMI category: {$category}. I'll align portions with your goal: {$goal}.",
        };
    }
}
