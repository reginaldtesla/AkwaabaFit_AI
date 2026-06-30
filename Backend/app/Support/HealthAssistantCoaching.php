<?php

namespace App\Support;

use App\Models\User;

/**
 * Condition, fasting, maternal, and activity-context coaching lines.
 */
class HealthAssistantCoaching
{
    /**
     * @return list<array{category: string, title: string, detail: string}>
     */
    public static function recommendationsFor(User $user): array
    {
        $recs = [];
        $conditions = self::conditions($user);
        $pattern = (string) ($user->eating_pattern ?? 'Regular');
        $lifeStage = (string) ($user->life_stage ?? 'General adult');
        $activityContext = (string) ($user->activity_context ?? 'Mixed');

        foreach ($conditions as $condition) {
            $tip = self::conditionTip($condition);
            if ($tip !== null) {
                $recs[] = [
                    'category' => 'health',
                    'title' => $tip['title'],
                    'detail' => $tip['detail'],
                ];
            }
        }

        if ($pattern !== 'Regular') {
            $recs[] = [
                'category' => 'faith',
                'title' => 'Eating pattern: '.$pattern,
                'detail' => self::fastingTip($pattern),
            ];
        }

        $maternal = self::maternalTip($lifeStage);
        if ($maternal !== null) {
            $recs[] = [
                'category' => 'maternal',
                'title' => $maternal['title'],
                'detail' => $maternal['detail'],
            ];
        }

        $activity = self::activityContextTip($activityContext);
        if ($activity !== null) {
            $recs[] = [
                'category' => 'activity',
                'title' => $activity['title'],
                'detail' => $activity['detail'],
            ];
        }

        return $recs;
    }

    /** @return list<string> */
    private static function conditions(User $user): array
    {
        $raw = $user->health_conditions;
        if (! is_array($raw)) {
            return [];
        }

        return array_values(array_filter(
            array_map(fn ($c) => trim((string) $c), $raw),
            fn (string $c) => $c !== '' && $c !== 'None',
        ));
    }

    /**
     * @return array{title: string, detail: string}|null
     */
    private static function conditionTip(string $condition): ?array
    {
        return match ($condition) {
            'High blood pressure' => [
                'title' => 'Blood pressure-friendly eating',
                'detail' => 'Go easy on salty shito and stock cubes. Favour kontomire, beans, grilled fish, and smaller soup portions—not extra oily stew.',
            ],
            'Diabetes' => [
                'title' => 'Steady blood sugar',
                'detail' => 'Pair banku, fufu, or large rice with protein (fish, eggs, beans). Avoid skipping meals then eating one huge evening chop.',
            ],
            'Anaemia' => [
                'title' => 'Iron-rich local foods',
                'detail' => 'Kontomire stew, beans (gobe), eggs, and lean meat in soup help. Pair plant iron with vitamin C from fresh pepper or fruit.',
            ],
            'Sickle cell' => [
                'title' => 'Stay hydrated & nourished',
                'detail' => 'Drink water steadily, especially in heat. Regular meals with protein and vegetables—avoid long fasts without your care team’s guidance.',
            ],
            'High cholesterol' => [
                'title' => 'Heart-friendly chops',
                'detail' => 'Choose grilled fish over deep-fried sides most days. Palm oil in moderation; load up on kontomire and garden egg stews.',
            ],
            default => null,
        };
    }

    private static function fastingTip(string $pattern): string
    {
        return match ($pattern) {
            'Ramadan' => 'Suhoor: koko, eggs, or light porridge with protein. Iftar: dates, water, then soup or rice—avoid breaking fast with only heavy fried plantain.',
            'Lent', 'Church fast days' => 'On fast days, plan one nourishing meal after—light soup, beans, or fish. Do not stack multiple heavy starch plates when you break.',
            'Intermittent fasting' => 'Keep your eating window to proper Ghanaian meals—still aim for protein at lunch or early dinner, not only snacks.',
            default => 'Adjust meal timing but keep balanced local plates when you eat.',
        };
    }

    /**
     * @return array{title: string, detail: string}|null
     */
    private static function maternalTip(string $lifeStage): ?array
    {
        return match ($lifeStage) {
            'Pregnant' => [
                'title' => 'Pregnancy nutrition',
                'detail' => 'Kontomire, beans, eggs, and fish support iron and folate. Avoid raw or undercooked meat; wash vegetables well. This app supports—not replaces—antenatal care.',
            ],
            'Breastfeeding' => [
                'title' => 'Breastfeeding fuel',
                'detail' => 'You need extra fluids and steady meals—groundnut soup, millet porridge, beans, and fish. Drink water before and after nursing.',
            ],
            'Caring for young child' => [
                'title' => 'Family plate awareness',
                'detail' => 'Children need smaller portions than adult chop bar sizes. Model balanced plates: starch + protein + vegetables, not only fried snacks.',
            ],
            default => null,
        };
    }

    /**
     * @return array{title: string, detail: string}|null
     */
    private static function activityContextTip(string $context): ?array
    {
        return match ($context) {
            'Market & trotro' => [
                'title' => 'On-your-feet day',
                'detail' => 'You already move a lot—fuel with waakye or rice and stew at lunch, water throughout, and a lighter kenkey or soup supper if tired.',
            ],
            'Office / desk' => [
                'title' => 'Desk-day movement',
                'detail' => 'Short walks at break, stairs, and an evening stroll matter. Keep lunch moderate—banku or jollof with protein, not double starch.',
            ],
            'Active job' => [
                'title' => 'Physical work day',
                'detail' => 'Higher step counts need steady carbs plus protein—do not skip lunch. Groundnuts or fruit between long shifts help.',
            ],
            'Student' => [
                'title' => 'Campus / school routine',
                'detail' => 'Budget-friendly gobe, eggs, and fruit beat skipping meals. Walk between classes to hit your step goal.',
            ],
            default => null,
        };
    }
}
