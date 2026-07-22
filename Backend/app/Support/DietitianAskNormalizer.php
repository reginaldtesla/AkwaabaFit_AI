<?php

namespace App\Support;

use Illuminate\Support\Str;

/**
 * Soft-correct messy Ghana English / food spelling before dietitian Q&A matching.
 */
class DietitianAskNormalizer
{
    /**
     * Common typos and local spellings → canonical tokens used by coaching rules.
     *
     * @var array<string, string>
     */
    private const REPLACEMENTS = [
        'loose weight' => 'lose weight',
        'loosing weight' => 'losing weight',
        'lossing weight' => 'losing weight',
        'lose wieght' => 'lose weight',
        'loose wieght' => 'lose weight',
        'weigth' => 'weight',
        'wieght' => 'weight',
        'watter' => 'water',
        'hydratation' => 'hydration',
        'jellof' => 'jollof',
        'jolof' => 'jollof',
        'jolloff' => 'jollof',
        'wakye' => 'waakye',
        'waakyeh' => 'waakye',
        'banko' => 'banku',
        'bancu' => 'banku',
        'kenke' => 'kenkey',
        'kinky' => 'kenkey',
        'fuufu' => 'fufu',
        'fofoo' => 'fufu',
        'kontomere' => 'kontomire',
        'kontomireh' => 'kontomire',
        'plantainn' => 'plantain',
        'plantein' => 'plantain',
        'keleweleh' => 'kelewele',
        'shitto' => 'shito',
        'ground nut' => 'groundnut',
        'calory' => 'calorie',
        'calories' => 'calories',
        'protien' => 'protein',
        'protiens' => 'protein',
        'dietry' => 'dietary',
        'healty' => 'healthy',
        'helthy' => 'healthy',
        'healhty' => 'healthy',
    ];

    public static function normalize(string $question): string
    {
        $clean = trim(preg_replace('/\s+/u', ' ', $question) ?? $question);
        if ($clean === '') {
            return '';
        }

        $lower = Str::lower($clean);
        foreach (self::REPLACEMENTS as $from => $to) {
            $lower = str_replace($from, $to, $lower);
        }

        // Preserve original casing lightly: return corrected lowercase for matching,
        // but keep a readable sentence for Gemini by rebuilding from tokens.
        return Str::limit($lower, 500, '');
    }

    /**
     * True when the text looks like trolling / unrelated chatter with no health signal.
     */
    public static function looksOffTopic(string $normalized): bool
    {
        $q = Str::lower(trim($normalized));
        if ($q === '') {
            return true;
        }

        if (preg_match('/\b(lol|lmao|haha|useless|nonsense|fool|stupid|waste time|bora|chale nothing|abt football|match score|crypto|betting|lottery|girlfriend|boyfriend|juju|sakawa)\b/u', $q)) {
            // Still allow if they also mention health food keywords.
            if (! self::hasHealthSignal($q)) {
                return true;
            }
        }

        if (self::hasHealthSignal($q)) {
            return false;
        }

        // Very short gibberish / random letters after normalization.
        if (strlen(preg_replace('/[^a-z0-9]/u', '', $q) ?? '') < 8) {
            return true;
        }

        // Long text with no diet/health vocabulary → gentle redirect.
        return ! preg_match(
            '/\b(eat|food|meal|diet|weight|bmi|water|drink|step|walk|exercise|health|hungry|fat|slim|gain|lose|protein|carb|calorie|jollof|waakye|banku|fufu|kenkey|soup|stew|plantain|beans|rice|fish|chicken|egg|portion|breakfast|lunch|dinner|supper|hydrat)/u',
            $q,
        );
    }

    public static function hasHealthSignal(string $normalized): bool
    {
        return (bool) preg_match(
            '/\b(eat|food|meal|diet|weight|bmi|water|drink|step|walk|exercise|health|hungry|slim|gain|lose|losing|protein|carb|calorie|jollof|waakye|banku|fufu|kenkey|soup|stew|plantain|beans|rice|fish|chicken|egg|portion|breakfast|lunch|dinner|supper|hydrat|healthy)/u',
            Str::lower($normalized),
        );
    }
}
