<?php

namespace App\Support;

/**
 * Neutral meal labels for History / coaching — never frames food as
 * "chop bar" or "vendor" food for the user.
 */
final class MealCopy
{
    public static function friendlyName(?string $name): string
    {
        $clean = trim((string) $name);
        if ($clean === '') {
            return '';
        }

        $clean = preg_replace('/\s*\(\s*chop\s*bar\s*\)/iu', '', $clean) ?? $clean;
        $clean = preg_replace('/\s*\(\s*vendor\s*\)/iu', '', $clean) ?? $clean;
        $clean = preg_replace('/\bchop\s*\(\s*vendor\s*\)/iu', 'chop', $clean) ?? $clean;
        $clean = preg_replace('/\s{2,}/', ' ', $clean) ?? $clean;

        return trim($clean);
    }

    public static function friendlyInsight(?string $insight): ?string
    {
        if ($insight === null) {
            return null;
        }

        $clean = trim($insight);
        if ($clean === '') {
            return null;
        }

        $replacements = [
            '/\bchop\s*bar\s+meals?\b/iu' => 'meals',
            '/\bchop\s*bar\s+portions?\b/iu' => 'portions',
            '/\bchop\s*bar\s+plate\b/iu' => 'plate',
            '/\bchop\s*bar\s+meal\s+plan\b/iu' => 'meal plan',
            '/\bchop\s*bar\s+sizes?\b/iu' => 'portion sizes',
            '/\bchop\s*bar\s+style\b/iu' => 'local style',
            '/\bfrom the chop bar\b/iu' => '',
            '/\bat the chop bar\b/iu' => '',
            '/\bhow chop bars serve it\b/iu' => 'a classic pairing',
            '/\bhow the vendor serves it\b/iu' => 'with your usual sides',
            '/\blike at the vendor\b/iu' => 'with your usual sides',
            '/\bfrom the vendor\b/iu' => '',
            '/\bvendors?\b/iu' => 'cooks',
            '/\bchop bars?\b/iu' => 'kitchens',
            '/\bfull chop bar portion\b/iu' => 'full portion',
        ];

        foreach ($replacements as $pattern => $replacement) {
            $clean = preg_replace($pattern, $replacement, $clean) ?? $clean;
        }

        $clean = preg_replace('/\s{2,}/', ' ', $clean) ?? $clean;
        $clean = preg_replace('/\s+([,.!?;:])/', '$1', $clean) ?? $clean;
        $clean = trim($clean);

        return $clean === '' ? null : $clean;
    }
}
