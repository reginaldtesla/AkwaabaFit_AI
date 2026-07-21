<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Safety Hub tips: keep a local dietitian tip bank, refresh with Gemini for variety.
 */
class SafetyHealthTipsService
{
    /**
     * @return array{tips: list<array{title: string, body: string, icon: string}>, source: string}
     */
    public function tips(
        ?float $tempCelsius = null,
        ?string $weatherMain = null,
        ?int $airQualityAqi = null,
        bool $forceRefresh = false,
    ): array {
        $local = $this->localTips();

        $cacheKey = 'safety_health_tips:v2:'.md5(json_encode([
            round($tempCelsius ?? 0),
            strtolower(trim((string) $weatherMain)),
            $airQualityAqi ?? 0,
            now()->format('Y-m-d-H'),
        ], JSON_THROW_ON_ERROR));

        if (! $forceRefresh && Cache::has($cacheKey)) {
            /** @var array{tips: list<array{title: string, body: string, icon: string}>, source: string} $cached */
            $cached = Cache::get($cacheKey);

            return $cached;
        }

        $gemini = $this->tryGeminiTips($tempCelsius, $weatherMain, $airQualityAqi, $local);
        if ($gemini === null) {
            $payload = [
                'tips' => $local,
                'source' => 'local',
            ];
            Cache::put($cacheKey, $payload, now()->addMinutes(20));

            return $payload;
        }

        $payload = [
            'tips' => $this->mergeTips($gemini, $local),
            'source' => 'mixed',
        ];
        Cache::put($cacheKey, $payload, now()->addMinutes(20));

        return $payload;
    }

    /**
     * Fresh Gemini tips first, then local bank (deduped by title).
     *
     * @param  list<array{title: string, body: string, icon: string}>  $fresh
     * @param  list<array{title: string, body: string, icon: string}>  $local
     * @return list<array{title: string, body: string, icon: string}>
     */
    private function mergeTips(array $fresh, array $local): array
    {
        $seen = [];
        $merged = [];

        foreach ([...$fresh, ...$local] as $tip) {
            $key = strtolower(trim($tip['title']));
            if ($key === '' || isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $merged[] = $tip;
            if (count($merged) >= 12) {
                break;
            }
        }

        return $merged;
    }

    /**
     * @param  list<array{title: string, body: string, icon: string}>  $localTips
     * @return list<array{title: string, body: string, icon: string}>|null
     */
    private function tryGeminiTips(
        ?float $tempCelsius,
        ?string $weatherMain,
        ?int $airQualityAqi,
        array $localTips,
    ): ?array {
        $apiKey = trim((string) config('services.food_scan.gemini_api_key', ''));
        if ($apiKey === '') {
            return null;
        }

        $existingTitles = array_values(array_map(
            fn (array $t) => $t['title'],
            $localTips,
        ));

        $context = [
            'temp_celsius' => $tempCelsius,
            'weather_main' => $weatherMain,
            'air_quality_aqi' => $airQualityAqi,
            'existing_local_tip_titles' => $existingTitles,
            'voice' => 'personal dietitian coach in AkwaabaFit',
        ];

        $prompt = 'You are the warm, professional registered dietitian inside AkwaabaFit, coaching one client. '
            .'Write short Safety Hub coaching tips in the same voice as the app dietitian: caring 2nd person ("you"), practical, not preachy, no medical diagnosis. '
            .'Tie tips to today\'s weather when useful (heat, rain, dusty air). Focus on hydration, shade, balanced plates, protein, salt awareness, steps, rest, and hygiene. '
            .'Do not name any country or nationality in titles or bodies. '
            .'Do NOT repeat these existing tip titles: '.json_encode($existingTitles, JSON_UNESCAPED_UNICODE).'. '
            .'JSON only: {"tips":[{"title":"max 40 chars","body":"max 160 chars, dietitian voice","icon":"water|shade|food|walk|rest|salt|protein|hygiene|morning|heart"}]}. '
            .'Return exactly 6 NEW tips that refresh the board with variety. Context: '
            .json_encode($context, JSON_UNESCAPED_UNICODE);

        $parsed = $this->geminiJson($prompt);
        if ($parsed === null) {
            return null;
        }

        return $this->normalizeTips($parsed);
    }

    /**
     * @param  array<string, mixed>  $parsed
     * @return list<array{title: string, body: string, icon: string}>|null
     */
    private function normalizeTips(array $parsed): ?array
    {
        $raw = $parsed['tips'] ?? null;
        if (! is_array($raw)) {
            return null;
        }

        $allowedIcons = [
            'water', 'shade', 'food', 'walk', 'rest', 'salt', 'protein', 'hygiene', 'morning', 'heart',
        ];

        $tips = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $title = trim((string) ($row['title'] ?? ''));
            $body = trim((string) ($row['body'] ?? ''));
            if ($title === '' || $body === '') {
                continue;
            }
            $icon = strtolower(trim((string) ($row['icon'] ?? 'heart')));
            if (! in_array($icon, $allowedIcons, true)) {
                $icon = 'heart';
            }
            $tips[] = [
                'title' => Str::limit($title, 48, ''),
                'body' => Str::limit($body, 180, ''),
                'icon' => $icon,
            ];
            if (count($tips) >= 6) {
                break;
            }
        }

        return count($tips) >= 3 ? $tips : null;
    }

    /**
     * Core local bank — always available; Gemini only refreshes/extends this.
     *
     * @return list<array{title: string, body: string, icon: string}>
     */
    private function localTips(): array
    {
        return [
            [
                'title' => 'Sip through the day',
                'body' => 'As your dietitian, I\'d rather you take small sips all day than wait until thirst hits—especially in the heat.',
                'icon' => 'water',
            ],
            [
                'title' => 'Shade over strain',
                'body' => 'When the sun is fierce, build shade breaks into your walk. I want you steady outdoors, not drained.',
                'icon' => 'shade',
            ],
            [
                'title' => 'Eat more colour',
                'body' => 'Add leafy greens, garden eggs, or tomatoes to today\'s plate—I coach colour because it quietly lifts iron and fibre.',
                'icon' => 'food',
            ],
            [
                'title' => 'Pace your steps',
                'body' => 'If the air feels dusty, keep outdoor walks shorter and easy. Your indoor steps still count toward the goal I set with you.',
                'icon' => 'walk',
            ],
            [
                'title' => 'Rest is recovery',
                'body' => 'Aim for solid sleep tonight. As your coach, I know rest steadies appetite, mood, and how hard movement feels tomorrow.',
                'icon' => 'rest',
            ],
            [
                'title' => 'Salt with care',
                'body' => 'Seasoned meals are fine—just go easy on extra table salt if we\'re watching your blood pressure habits.',
                'icon' => 'salt',
            ],
            [
                'title' => 'Protein at meals',
                'body' => 'Pair your starch with beans, eggs, fish, or lean meat so your energy lasts between meals.',
                'icon' => 'protein',
            ],
            [
                'title' => 'Wash hands, stay well',
                'body' => 'Clean hands before meals and after being out—simple hygiene that keeps your nutrition plan on track.',
                'icon' => 'hygiene',
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function geminiJson(string $prompt): ?array
    {
        $apiKey = trim((string) config('services.food_scan.gemini_api_key', ''));
        if ($apiKey === '') {
            return null;
        }

        $model = (string) config('services.food_scan.gemini_model', 'gemini-2.5-flash');
        $timeout = (int) config('services.dietitian.gemini_timeout', 45);
        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent";

        try {
            $response = Http::timeout($timeout)
                ->withQueryParameters(['key' => $apiKey])
                ->post($url, [
                    'contents' => [
                        ['parts' => [['text' => $prompt]]],
                    ],
                    'generationConfig' => [
                        'temperature' => 0.8,
                        'responseMimeType' => 'application/json',
                    ],
                ]);
        } catch (\Throwable $e) {
            Log::warning('Safety tips Gemini request failed', ['error' => $e->getMessage()]);

            return null;
        }

        if (! $response->successful()) {
            Log::warning('Safety tips Gemini HTTP error', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return null;
        }

        $text = data_get($response->json(), 'candidates.0.content.parts.0.text');
        if (! is_string($text) || trim($text) === '') {
            return null;
        }

        $decoded = json_decode(trim($text), true);

        return is_array($decoded) ? $decoded : null;
    }
}
