<?php

namespace App\Support;

/**
 * Realistic Ghanaian meal pairings (staple + soup/stew + protein/sides).
 *
 * @see https://en.wikipedia.org/wiki/Ghanaian_cuisine
 * @see https://www.remitly.com/blog/food/meal-times-in-ghana/
 */
class GhanaianMealSuggestions
{
    /**
     * @return array{suggestion: string, reason: string}
     */
    public static function nextMeal(
        int $mealsLoggedToday = 0,
        string $goal = '',
        int $remainingKcal = 0,
        int $proteinGap = 0,
        ?int $hourAccra = null,
    ): array {
        $hour = $hourAccra ?? (int) now('Africa/Accra')->format('G');

        if ($proteinGap > 25) {
            return self::pick([
                [
                    'suggestion' => 'Banku with grilled tilapia and shito',
                    'reason' => 'A proper Accra-style plate—fish for protein, banku for energy.',
                ],
                [
                    'suggestion' => 'Waakye with boiled egg, shito and a little fish',
                    'reason' => 'Street-style waakye chop gives protein without skipping the flavours you know.',
                ],
                [
                    'suggestion' => 'Red-red (gobe) with fried ripe plantain',
                    'reason' => 'Beans stew and plantain—filling plant protein Ghanaians actually eat.',
                ],
            ]);
        }

        if ($remainingKcal < -250) {
            return self::pick([
                [
                    'suggestion' => 'Kenkey with grilled fish and pepper (small ball)',
                    'reason' => 'Classic lighter dinner—keep the kenkey modest after a heavy day.',
                ],
                [
                    'suggestion' => 'Light soup with a small fufu ball',
                    'reason' => 'Warm soup and less starch—how many families eat on a light evening.',
                ],
            ]);
        }

        if ($goal === 'Gain weight' && $remainingKcal > 450) {
            return self::pick([
                [
                    'suggestion' => 'Waakye chop — rice & beans, stew, gari, egg and plantain',
                    'reason' => 'Full waakye plate is calorie-dense and very Ghana.',
                ],
                [
                    'suggestion' => 'Fufu with groundnut soup and meat',
                    'reason' => 'Hearty chop that fills you up the Ghanaian way.',
                ],
            ]);
        }

        if ($mealsLoggedToday === 0) {
            return self::mealForTimeOfDay($hour);
        }

        if ($mealsLoggedToday === 1) {
            return self::pick([
                [
                    'suggestion' => 'Jollof rice with chicken and salad',
                    'reason' => 'Solid lunch chop—tomato rice plus protein, just like chop bars serve it.',
                ],
                [
                    'suggestion' => 'Banku with okro stew',
                    'reason' => 'The pairing Ghanaians argue about least—banku and okro is home.',
                ],
                [
                    'suggestion' => 'Kenkey with fried fish and shito',
                    'reason' => 'Evening favourite along the coast—fish, pepper, kenkey.',
                ],
            ]);
        }

        return self::pick([
            [
                'suggestion' => 'Boiled yam (ampesi) with kontomire stew and egg',
                'reason' => 'Kontomire belongs with boiled yam or rice—not random sides.',
            ],
            [
                'suggestion' => 'Plain rice with stew and kontomire on the side',
                'reason' => 'Simple Sunday-style plate many households still eat.',
            ],
            [
                'suggestion' => 'Kelewele with groundnuts as a small chop',
                'reason' => 'If you need a snack, spicy plantain and groundnuts beat odd combos.',
            ],
        ]);
    }

    /**
     * @return array{suggestion: string, reason: string}
     */
    private static function mealForTimeOfDay(int $hour): array
    {
        // Breakfast window (~6–10): waakye, koko, bread
        if ($hour >= 5 && $hour < 11) {
            return self::pick([
                [
                    'suggestion' => 'Waakye with shito, gari, boiled egg and plantain',
                    'reason' => 'Morning waakye chop from the vendor—how Accra and Kumasi start the day.',
                ],
                [
                    'suggestion' => 'Hausa koko with koose (or bofrot)',
                    'reason' => 'Northern-style breakfast many Ghanaians grew up on—not koko with boiled egg.',
                ],
                [
                    'suggestion' => 'Tea bread with eggs and tea',
                    'reason' => 'Quick urban breakfast when you are not buying waakye yet.',
                ],
            ]);
        }

        // Lunch (~11–15): heaviest meal
        if ($hour >= 11 && $hour < 16) {
            return self::pick([
                [
                    'suggestion' => 'Banku with grilled tilapia and pepper',
                    'reason' => 'Probably Ghana’s most photographed lunch—coastal chop bars live on this.',
                ],
                [
                    'suggestion' => 'Jollof with chicken or fish',
                    'reason' => 'Office lunch, party jollof, chop bar jollof—same spirit.',
                ],
                [
                    'suggestion' => 'Fufu with light soup or groundnut soup',
                    'reason' => 'Proper midday chop when you want soup and swallow.',
                ],
            ]);
        }

        // Dinner (~16–22): kenkey, lighter soup, waakye still fine
        if ($hour >= 16 && $hour < 23) {
            return self::pick([
                [
                    'suggestion' => 'Kenkey with fried fish and shito',
                    'reason' => 'Classic evening meal—Ga kenkey, fish, pepper sauce.',
                ],
                [
                    'suggestion' => 'Banku with okro stew',
                    'reason' => 'Lighter than a big fufu chop but still fully Ghanaian.',
                ],
                [
                    'suggestion' => 'Waakye (smaller portion) with stew and egg',
                    'reason' => 'Waakye is not only morning food—many people eat it for supper too.',
                ],
            ]);
        }

        return [
            'suggestion' => 'Light soup with small fufu',
            'reason' => 'Late night—warm soup beats a heavy starch plate.',
        ];
    }

    public static function pairingForFood(string $slug): ?string
    {
        return match (true) {
            str_contains($slug, 'banku') => 'Okro stew, grilled tilapia with shito, or palm nut soup—not random sides.',
            str_contains($slug, 'kenkey') => 'Fried or grilled fish with shito and hot pepper.',
            str_contains($slug, 'fufu') => 'Light soup, groundnut soup, or palm nut soup.',
            str_contains($slug, 'jollof') => 'Chicken, fish, or kelewele on the side—not eaten plain.',
            str_contains($slug, 'waakye') => 'Shito, gari, spaghetti, boiled egg, plantain—pick what the vendor offers.',
            str_contains($slug, 'beans') || str_contains($slug, 'gobe') || str_contains($slug, 'red') => 'Fried ripe plantain (red-red) or plain rice.',
            str_contains($slug, 'rice') && ! str_contains($slug, 'jollof') => 'Stew with kontomire or salad—chop bar style.',
            str_contains($slug, 'yam') => 'Kontomire stew, garden eggs stew, or palm oil stew.',
            str_contains($slug, 'plantain') => 'With beans stew, or as kelewele beside rice or jollof.',
            str_contains($slug, 'kontomire') => 'Boiled yam, rice, or banku—not usually the main banku pairing.',
            default => null,
        };
    }

    /**
     * @return list<string>
     */
    public static function geminiAuthenticityRules(): array
    {
        return [
            'Only suggest meals Ghanaians commonly eat: staple + soup/stew + protein/sides.',
            'Real combos: banku+okro, banku+tilapia+shito, kenkey+fried fish+shito, waakye+shito+gari+egg+plantain, fufu+light/groundnut soup, jollof+chicken/fish, red-red+plantain, ampesi yam+kontomire.',
            'Do NOT invent odd pairings (e.g. banku with kontomire stew, koko with boiled egg only, fusion plates).',
            'Breakfast: waakye chop, koko+koose, tea bread+eggs—not generic Western breakfast.',
            'Name dishes the way Ghanaians say them: waakye, banku, shito, gobe, chop bar, light soup.',
        ];
    }

    /**
     * @param  list<array{suggestion: string, reason: string}>  $options
     * @return array{suggestion: string, reason: string}
     */
    private static function pick(array $options): array
    {
        if ($options === []) {
            return [
                'suggestion' => 'Banku with okro stew',
                'reason' => 'A familiar Ghanaian plate.',
            ];
        }

        $index = (int) now()->format('z') % count($options);

        return $options[$index];
    }
}
