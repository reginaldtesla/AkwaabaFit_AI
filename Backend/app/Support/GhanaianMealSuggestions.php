<?php

namespace App\Support;

/**
 * Realistic Ghanaian meal pairings with time-of-day awareness.
 *
 * @see https://en.wikipedia.org/wiki/Ghanaian_cuisine
 */
class GhanaianMealSuggestions
{
    /** Early morning chop: ~5:00–9:59 */
    private const SLOT_EARLY_MORNING = 'early_morning';

    /** Late morning / brunch: ~10:00–11:59 */
    private const SLOT_LATE_MORNING = 'late_morning';

    /** Main midday meal: ~12:00–14:59 */
    private const SLOT_LUNCH = 'lunch';

    /** Afternoon snack or light chop: ~15:00–16:59 */
    private const SLOT_AFTERNOON = 'afternoon';

    /** Evening supper: ~17:00–21:59 */
    private const SLOT_EVENING = 'evening';

    /** After 22:00 — only very light options */
    private const SLOT_LATE_NIGHT = 'late_night';

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
        $occasion = self::resolveOccasion($hour, $mealsLoggedToday);

        if ($proteinGap > 25) {
            return self::pickForOccasion(self::proteinRichMeals(), $occasion, $hour);
        }

        if ($remainingKcal < -250) {
            return self::pickForOccasion(self::lighterMeals(), $occasion, $hour);
        }

        if ($goal === 'Gain weight' && $remainingKcal > 450) {
            return self::pickForOccasion(self::calorieDenseMeals(), $occasion, $hour);
        }

        return self::pickForOccasion(self::mealsForOccasion($occasion), $occasion, $hour);
    }

    public static function pairingForFood(string $slug): ?string
    {
        return match (true) {
            str_contains($slug, 'banku') => 'Okro stew, grilled tilapia with shito, or palm nut soup—not random sides.',
            str_contains($slug, 'kenkey') => 'Fried or grilled fish with shito and hot pepper.',
            str_contains($slug, 'fufu') => 'Light soup, groundnut soup, or palm nut soup.',
            str_contains($slug, 'jollof') => 'Chicken, fish, or kelewele on the side—not eaten plain.',
            str_contains($slug, 'waakye') => 'Shito, gari, spaghetti, boiled egg, plantain—pick the sides that fit your plate.',
            str_contains($slug, 'beans') || str_contains($slug, 'gobe') || str_contains($slug, 'red') => 'Fried ripe plantain (red-red) or plain rice.',
            str_contains($slug, 'rice') && ! str_contains($slug, 'jollof') => 'Stew with kontomire or salad on the side.',
            str_contains($slug, 'yam') => 'Kontomire stew, garden eggs stew, or palm oil stew.',
            str_contains($slug, 'plantain') => 'With beans stew, or as kelewele beside rice or jollof.',
            str_contains($slug, 'kontomire') => 'Boiled yam, rice, or ampesi—not usually the main banku pairing.',
            str_contains($slug, 'koko') => 'Koose or bofrot—morning or afternoon, not a supper plate.',
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
            'Match food to time of day in Ghana (Africa/Accra): waakye and koko in the morning or afternoon; banku, jollof, fufu at lunch; kenkey and light soup in the evening; never suggest heavy fufu or kenkey as breakfast.',
            'Hausa koko with koose fits morning or afternoon—not dinner. Kenkey with fish is evening food. Waakye works morning through early evening.',
            'Real combos: banku+okro, banku+tilapia+shito, kenkey+fried fish+shito, waakye+shito+gari+egg+plantain, fufu+light/groundnut soup, jollof+chicken/fish, red-red+plantain, ampesi yam+kontomire.',
            'Do NOT invent odd pairings or serve dishes at the wrong time of day.',
            'Name dishes the way Ghanaians say them: waakye, banku, shito, gobe, light soup.',
            'Do not label meals as chop-bar food, vendor food, or street-vendor food when speaking to the user.',
        ];
    }

    private static function resolveOccasion(int $hour, int $mealsLoggedToday): string
    {
        if ($mealsLoggedToday === 0) {
            return self::slotForHour($hour);
        }

        if ($mealsLoggedToday === 1) {
            return match (true) {
                $hour < 12 => self::SLOT_LUNCH,
                $hour < 17 => self::SLOT_AFTERNOON,
                default => self::SLOT_EVENING,
            };
        }

        return match (true) {
            $hour < 17 => self::SLOT_AFTERNOON,
            $hour < 22 => self::SLOT_EVENING,
            default => self::SLOT_LATE_NIGHT,
        };
    }

    private static function slotForHour(int $hour): string
    {
        return match (true) {
            $hour >= 5 && $hour < 10 => self::SLOT_EARLY_MORNING,
            $hour >= 10 && $hour < 12 => self::SLOT_LATE_MORNING,
            $hour >= 12 && $hour < 15 => self::SLOT_LUNCH,
            $hour >= 15 && $hour < 17 => self::SLOT_AFTERNOON,
            $hour >= 17 && $hour < 22 => self::SLOT_EVENING,
            default => self::SLOT_LATE_NIGHT,
        };
    }

    /**
     * @return list<array{suggestion: string, reason: string, slots: list<string>}>
     */
    private static function proteinRichMeals(): array
    {
        return [
            [
                'suggestion' => 'Waakye with boiled egg, shito and fish',
                'reason' => 'Morning or afternoon waakye chop—protein without skipping the flavours you know.',
                'slots' => [self::SLOT_EARLY_MORNING, self::SLOT_LATE_MORNING, self::SLOT_LUNCH, self::SLOT_AFTERNOON],
            ],
            [
                'suggestion' => 'Banku with grilled tilapia and shito',
                'reason' => 'A proper lunch or early-evening plate—fish for protein, banku for energy.',
                'slots' => [self::SLOT_LUNCH, self::SLOT_EVENING],
            ],
            [
                'suggestion' => 'Red-red (gobe) with fried ripe plantain',
                'reason' => 'Beans stew and plantain—filling plant protein for lunch or afternoon.',
                'slots' => [self::SLOT_LUNCH, self::SLOT_AFTERNOON],
            ],
            [
                'suggestion' => 'Kenkey with grilled fish and pepper',
                'reason' => 'Classic supper protein—save kenkey for when Ghanaians normally eat it.',
                'slots' => [self::SLOT_EVENING],
            ],
        ];
    }

    /**
     * @return list<array{suggestion: string, reason: string, slots: list<string>}>
     */
    private static function lighterMeals(): array
    {
        return [
            [
                'suggestion' => 'Kenkey with grilled fish and pepper (small ball)',
                'reason' => 'Classic lighter supper—keep the kenkey modest after a heavy day.',
                'slots' => [self::SLOT_EVENING],
            ],
            [
                'suggestion' => 'Light soup with a small fufu ball',
                'reason' => 'Warm evening soup with less starch—fits a light night plate.',
                'slots' => [self::SLOT_EVENING, self::SLOT_LATE_NIGHT],
            ],
            [
                'suggestion' => 'Hausa koko with koose',
                'reason' => 'Light afternoon koko—fills you without a heavy chop bar plate.',
                'slots' => [self::SLOT_AFTERNOON, self::SLOT_LATE_MORNING],
            ],
            [
                'suggestion' => 'Tea bread with eggs',
                'reason' => 'Simple morning bite when you want something lighter today.',
                'slots' => [self::SLOT_EARLY_MORNING, self::SLOT_LATE_MORNING],
            ],
        ];
    }

    /**
     * @return list<array{suggestion: string, reason: string, slots: list<string>}>
     */
    private static function calorieDenseMeals(): array
    {
        return [
            [
                'suggestion' => 'Waakye chop — rice & beans, stew, gari, egg and plantain',
                'reason' => 'Full waakye plate for morning or afternoon—calorie-dense and very Ghana.',
                'slots' => [self::SLOT_EARLY_MORNING, self::SLOT_LATE_MORNING, self::SLOT_LUNCH, self::SLOT_AFTERNOON],
            ],
            [
                'suggestion' => 'Fufu with groundnut soup and meat',
                'reason' => 'Hearty lunch chop that fills you up the Ghanaian way.',
                'slots' => [self::SLOT_LUNCH],
            ],
            [
                'suggestion' => 'Jollof rice with chicken and salad',
                'reason' => 'Proper midday jollof—save the big rice plates for lunch hour.',
                'slots' => [self::SLOT_LUNCH],
            ],
        ];
    }

    /**
     * @return list<array{suggestion: string, reason: string, slots: list<string>}>
     */
    private static function mealsForOccasion(string $occasion): array
    {
        $catalog = [
            // Morning
            [
                'suggestion' => 'Waakye with shito, gari, boiled egg and plantain',
                'reason' => 'Morning waakye from the vendor—how Accra and Kumasi start the day.',
                'slots' => [self::SLOT_EARLY_MORNING, self::SLOT_LATE_MORNING],
            ],
            [
                'suggestion' => 'Hausa koko with koose (or bofrot)',
                'reason' => 'Northern-style porridge—morning or afternoon, with koose like the women sell it.',
                'slots' => [self::SLOT_EARLY_MORNING, self::SLOT_LATE_MORNING, self::SLOT_AFTERNOON],
            ],
            [
                'suggestion' => 'Tea bread with eggs and tea',
                'reason' => 'Quick urban breakfast before work or school.',
                'slots' => [self::SLOT_EARLY_MORNING, self::SLOT_LATE_MORNING],
            ],
            // Lunch
            [
                'suggestion' => 'Banku with grilled tilapia and pepper',
                'reason' => 'Iconic midday chop—coastal chop bars live on this at lunch.',
                'slots' => [self::SLOT_LUNCH],
            ],
            [
                'suggestion' => 'Jollof with chicken or fish',
                'reason' => 'Office lunch, party jollof, chop bar jollof—all lunch-hour food.',
                'slots' => [self::SLOT_LUNCH],
            ],
            [
                'suggestion' => 'Fufu with light soup or groundnut soup',
                'reason' => 'Proper soup-and-swallow for the main meal of the day.',
                'slots' => [self::SLOT_LUNCH],
            ],
            [
                'suggestion' => 'Plain rice with stew and kontomire',
                'reason' => 'Sunday-style household lunch many families still eat.',
                'slots' => [self::SLOT_LUNCH],
            ],
            // Afternoon
            [
                'suggestion' => 'Waakye with stew and egg (smaller portion)',
                'reason' => 'Afternoon waakye is normal—vendors still have the pot going.',
                'slots' => [self::SLOT_AFTERNOON],
            ],
            [
                'suggestion' => 'Kelewele with groundnuts',
                'reason' => 'Afternoon street snack—not a full dinner plate.',
                'slots' => [self::SLOT_AFTERNOON],
            ],
            [
                'suggestion' => 'Boiled yam (ampesi) with kontomire stew and egg',
                'reason' => 'Light afternoon ampesi plate when you want something before supper.',
                'slots' => [self::SLOT_AFTERNOON],
            ],
            // Evening
            [
                'suggestion' => 'Kenkey with fried fish and shito',
                'reason' => 'Classic Ga supper—kenkey belongs in the evening.',
                'slots' => [self::SLOT_EVENING],
            ],
            [
                'suggestion' => 'Banku with okro stew',
                'reason' => 'Lighter evening banku—many eat okro after work.',
                'slots' => [self::SLOT_EVENING],
            ],
            [
                'suggestion' => 'Waakye with stew and egg',
                'reason' => 'Early-evening waakye before vendors pack up—still a normal chop.',
                'slots' => [self::SLOT_EVENING],
            ],
            // Late night
            [
                'suggestion' => 'Light soup with small fufu',
                'reason' => 'Late night—warm soup beats a heavy starch plate.',
                'slots' => [self::SLOT_LATE_NIGHT],
            ],
        ];

        return array_values(array_filter(
            $catalog,
            fn (array $meal): bool => in_array($occasion, $meal['slots'], true),
        ));
    }

    /**
     * @param  list<array{suggestion: string, reason: string, slots: list<string>}>  $options
     * @return array{suggestion: string, reason: string}
     */
    private static function pickForOccasion(array $options, string $occasion, int $hour): array
    {
        $filtered = array_values(array_filter(
            $options,
            fn (array $meal): bool => in_array($occasion, $meal['slots'], true),
        ));

        if ($filtered === []) {
            $filtered = self::mealsForOccasion($occasion);
        }

        if ($filtered === []) {
            $filtered = self::mealsForOccasion(self::slotForHour($hour));
        }

        return self::pick($filtered);
    }

    /**
     * @param  list<array{suggestion: string, reason: string, slots?: list<string>}>  $options
     * @return array{suggestion: string, reason: string}
     */
    private static function pick(array $options): array
    {
        if ($options === []) {
            return [
                'suggestion' => 'Banku with okro stew',
                'reason' => 'A familiar Ghanaian plate for the evening.',
            ];
        }

        $index = (int) now('Africa/Accra')->format('z') % count($options);
        $choice = $options[$index];

        return [
            'suggestion' => $choice['suggestion'],
            'reason' => $choice['reason'],
        ];
    }
}
