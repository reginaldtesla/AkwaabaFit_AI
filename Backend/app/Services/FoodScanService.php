<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

/**
 * Hybrid Ghana food scan:
 * 1) Kennethdot ConvNeXt (Hugging Face) — Ghana-trained classifier
 * 2) Gemini Flash (Google AI Studio free tier) — fallback for low confidence / mixed plates
 */
class FoodScanService
{
    /**
     * Closed vocabulary for Gemini — must match nutrition catalog class_name values.
     *
     * @var list<string>
     */
    private const CATALOG_CLASS_NAMES = [
        'banku',
        'beans',
        'bread',
        'burger',
        'chicken',
        'egg-pepper',
        'fufu',
        'hausa-koko',
        'jollof',
        'kelewele',
        'kenkey',
        'kokonte',
        'koose',
        'kontomire',
        'meat',
        'nkate-cake',
        'okro',
        'pasta',
        'pizza',
        'plantain',
        'rice',
        'salad',
        'waakye',
        'yam',
        'groundnut-soup',
        'palmnut-soup',
        'shito',
        'tilapia',
        'fish',
        'ebunubunu',
        'apapransa',
        'tubaani',
        'kyinkyinga',
    ];

    /** Maps HF Ghana model labels → nutrition catalog slugs. */
    private const GHANA_LABEL_ALIASES = [
        'jollof rice ghana' => 'jollof',
        'jollof rice' => 'jollof',
        'jollof' => 'jollof',
        'ghana jollof' => 'jollof',
        'party jollof' => 'jollof',
        'banku ghana' => 'banku',
        'banku' => 'banku',
        'banku and tilapia' => 'banku',
        'banku with okro' => 'banku',
        'banku with okra' => 'banku',
        'fufu ghana' => 'fufu',
        'fufu' => 'fufu',
        'fufu and light soup' => 'fufu',
        'fufu with soup' => 'fufu',
        'kenkey ghana' => 'kenkey',
        'fante kenkey' => 'kenkey',
        'ga kenkey' => 'kenkey',
        'kenkey' => 'kenkey',
        'kenkey and fish' => 'kenkey',
        'kelewele ghana' => 'kelewele',
        'kelewele' => 'kelewele',
        'waakye' => 'waakye',
        'waakye ghana' => 'waakye',
        'wakye' => 'waakye',
        'kokonte' => 'kokonte',
        'konkonte' => 'kokonte',
        'kokonte ghana' => 'kokonte',
        'koose ghana' => 'koose',
        'koose' => 'koose',
        'kose' => 'koose',
        'akara' => 'koose',
        'red red ghana' => 'beans',
        'red red' => 'beans',
        'red-red' => 'beans',
        'gobe' => 'beans',
        'gobe ghana' => 'beans',
        'gobƐ ghana' => 'beans',
        'beans stew' => 'beans',
        'beans and plantain' => 'beans',
        'roasted plaintain ghana' => 'plantain',
        'roasted plantain ghana' => 'plantain',
        'roasted plantain' => 'plantain',
        'fried plantain' => 'plantain',
        'fried plaintain' => 'plantain',
        'ripe plantain' => 'plantain',
        'plantain' => 'plantain',
        'plaintain' => 'plantain',
        'kontomire stew ghana' => 'kontomire',
        'kontomire stew' => 'kontomire',
        'kontomire' => 'kontomire',
        'palava sauce' => 'kontomire',
        'palaver sauce' => 'kontomire',
        'yam porridge ghana' => 'yam',
        'yam porridge' => 'yam',
        'ampesi' => 'yam',
        'boiled yam' => 'yam',
        'yam' => 'yam',
        'gari soakings' => 'rice',
        'omotuo' => 'rice',
        'omotuo ghana' => 'rice',
        'plain rice' => 'rice',
        'white rice' => 'rice',
        'rice' => 'rice',
        'tatale ghana' => 'kelewele',
        'tatale' => 'kelewele',
        'okro stew ghana' => 'okro',
        'okro stew' => 'okro',
        'okra stew' => 'okro',
        'okro soup' => 'okro',
        'okra soup' => 'okro',
        'okro' => 'okro',
        'okra' => 'okro',
        'groundnut soup ghana' => 'groundnut-soup',
        'groundnut soup' => 'groundnut-soup',
        'peanut soup' => 'groundnut-soup',
        'nkate nkwan' => 'groundnut-soup',
        'palmnut soup ghana' => 'palmnut-soup',
        'palmnut soup' => 'palmnut-soup',
        'palm nut soup' => 'palmnut-soup',
        'abɛnkwan' => 'palmnut-soup',
        'abenkwan' => 'palmnut-soup',
        'light soup' => 'groundnut-soup',
        'ebunubunu ghana' => 'ebunubunu',
        'ebunubunu' => 'ebunubunu',
        'apapransa ghana' => 'apapransa',
        'apapransa' => 'apapransa',
        'tubaani ghana' => 'tubaani',
        'tubaani' => 'tubaani',
        'kyinkyinga ghana' => 'kyinkyinga',
        'kyinkyinga' => 'kyinkyinga',
        'chichinga' => 'kyinkyinga',
        'suya' => 'kyinkyinga',
        'zaafi ghana' => 'fufu',
        'zaafi' => 'fufu',
        'tz' => 'fufu',
        'tuo zaafi' => 'fufu',
        'shito' => 'shito',
        'black pepper sauce' => 'shito',
        'grilled tilapia' => 'tilapia',
        'fried tilapia' => 'tilapia',
        'tilapia' => 'tilapia',
        'grilled fish' => 'fish',
        'fried fish' => 'fish',
        'fish' => 'fish',
        'egg' => 'egg-pepper',
        'boiled egg' => 'egg-pepper',
        'egg stew' => 'egg-pepper',
        'egg and pepper' => 'egg-pepper',
        'egg pepper' => 'egg-pepper',
        'beans' => 'beans',
        'chicken' => 'chicken',
        'fried chicken' => 'chicken',
        'grilled chicken' => 'chicken',
        'meat' => 'meat',
        'goat meat' => 'meat',
        'beef' => 'meat',
        'hausa koko' => 'hausa-koko',
        'koko' => 'hausa-koko',
        'nkate cake' => 'nkate-cake',
        'peanut cake' => 'nkate-cake',
    ];

    /** Maps Gemini / free-text names → nutrition catalog slugs. */
    private const SLM_ALIASES = [
        'jollof rice' => 'jollof',
        'jollof' => 'jollof',
        'ghana jollof' => 'jollof',
        'banku and tilapia' => 'banku',
        'banku with tilapia' => 'banku',
        'banku' => 'banku',
        'fufu' => 'fufu',
        'fufu and soup' => 'fufu',
        'waakye' => 'waakye',
        'wakye' => 'waakye',
        'kenkey' => 'kenkey',
        'fante kenkey' => 'kenkey',
        'ga kenkey' => 'kenkey',
        'kelewele' => 'kelewele',
        'plantain' => 'plantain',
        'fried plantain' => 'plantain',
        'roasted plantain' => 'plantain',
        'plaintain' => 'plantain',
        'boiled egg' => 'egg-pepper',
        'egg-pepper' => 'egg-pepper',
        'egg pepper' => 'egg-pepper',
        'egg stew' => 'egg-pepper',
        'hausa koko' => 'hausa-koko',
        'koko' => 'hausa-koko',
        'kokonte' => 'kokonte',
        'konkonte' => 'kokonte',
        'koose' => 'koose',
        'kose' => 'koose',
        'akara' => 'koose',
        'nkate cake' => 'nkate-cake',
        'plain rice' => 'rice',
        'white rice' => 'rice',
        'omotuo' => 'rice',
        'rice' => 'rice',
        'yam' => 'yam',
        'ampesi' => 'yam',
        'yam porridge' => 'yam',
        'beans' => 'beans',
        'red red' => 'beans',
        'red-red' => 'beans',
        'gobe' => 'beans',
        'kontomire' => 'kontomire',
        'kontomire stew' => 'kontomire',
        'palava sauce' => 'kontomire',
        'okro' => 'okro',
        'okra' => 'okro',
        'okro stew' => 'okro',
        'okra stew' => 'okro',
        'groundnut soup' => 'groundnut-soup',
        'groundnut-soup' => 'groundnut-soup',
        'peanut soup' => 'groundnut-soup',
        'palmnut soup' => 'palmnut-soup',
        'palmnut-soup' => 'palmnut-soup',
        'palm nut soup' => 'palmnut-soup',
        'shito' => 'shito',
        'tilapia' => 'tilapia',
        'grilled tilapia' => 'tilapia',
        'fish' => 'fish',
        'fried fish' => 'fish',
        'ebunubunu' => 'ebunubunu',
        'apapransa' => 'apapransa',
        'tubaani' => 'tubaani',
        'kyinkyinga' => 'kyinkyinga',
        'chichinga' => 'kyinkyinga',
        'suya' => 'kyinkyinga',
        'zaafi' => 'fufu',
        'tuo zaafi' => 'fufu',
        'bread' => 'bread',
        'burger' => 'burger',
        'pizza' => 'pizza',
        'pasta' => 'pasta',
        'salad' => 'salad',
        'chicken' => 'chicken',
        'meat' => 'meat',
        'goat meat' => 'meat',
        'beef' => 'meat',
    ];

    /** @var array<string, string> */
    private const DISPLAY_NAMES = [
        'banku' => 'Banku',
        'beans' => 'Beans (red red)',
        'bread' => 'Bread',
        'burger' => 'Burger',
        'chicken' => 'Chicken',
        'egg-pepper' => 'Egg & pepper stew',
        'fufu' => 'Fufu',
        'hausa-koko' => 'Hausa koko',
        'jollof' => 'Jollof rice',
        'kelewele' => 'Kelewele',
        'kenkey' => 'Kenkey',
        'kokonte' => 'Kokonte',
        'koose' => 'Koose',
        'kontomire' => 'Kontomire stew',
        'meat' => 'Meat',
        'nkate-cake' => 'Nkate cake',
        'okro' => 'Okro stew',
        'pasta' => 'Pasta',
        'pizza' => 'Pizza',
        'plantain' => 'Plantain',
        'rice' => 'Rice',
        'salad' => 'Salad',
        'waakye' => 'Waakye',
        'yam' => 'Yam',
        'groundnut-soup' => 'Groundnut soup',
        'palmnut-soup' => 'Palmnut soup',
        'shito' => 'Shito',
        'tilapia' => 'Tilapia',
        'fish' => 'Fish',
        'ebunubunu' => 'Ebunubunu',
        'apapransa' => 'Apapransa',
        'tubaani' => 'Tubaani',
        'kyinkyinga' => 'Kyinkyinga',
    ];

    /**
     * @return array{
     *   provider: string,
     *   strategy: string,
     *   detections: list<array{class_name: string, display_name: string, confidence: float, source: string}>
     * }
     */
    public function scan(UploadedFile $image): array
    {
        $hfThreshold = (float) config('services.food_scan.hf_confidence_threshold', 0.55);
        $hfRows = $this->scanGhanaClassifier($image);

        $hfBest = $hfRows[0] ?? null;
        if ($hfBest !== null && $hfBest['confidence'] >= $hfThreshold) {
            $normalized = $this->applyConfidenceFloor(
                $this->normalizeRows($hfRows, self::GHANA_LABEL_ALIASES, 'ghana_classifier')
            );
            if ($normalized !== []) {
                return [
                    'provider' => 'hybrid',
                    'strategy' => 'ghana_classifier',
                    'detections' => $normalized,
                ];
            }
        }

        $geminiRows = $this->scanGeminiFlash($image);
        $geminiNorm = $this->applyConfidenceFloor(
            $this->normalizeRows($geminiRows, self::SLM_ALIASES, 'gemini_flash')
        );

        if ($geminiNorm !== []) {
            if ($hfBest !== null) {
                $geminiNorm = $this->applyConfidenceFloor(
                    $this->boostIfAgrees($hfBest, $geminiNorm)
                );
            }

            if ($geminiNorm !== []) {
                return [
                    'provider' => 'hybrid',
                    'strategy' => 'gemini_flash_fallback',
                    'detections' => $geminiNorm,
                ];
            }
        }

        if ($hfBest !== null) {
            $normalized = $this->applyConfidenceFloor(
                $this->normalizeRows($hfRows, self::GHANA_LABEL_ALIASES, 'ghana_classifier')
            );
            if ($normalized !== []) {
                return [
                    'provider' => 'hybrid',
                    'strategy' => 'ghana_classifier_low_confidence',
                    'detections' => $normalized,
                ];
            }
        }

        return [
            'provider' => 'hybrid',
            'strategy' => 'none',
            'detections' => [],
        ];
    }

    /**
     * @return list<array{name: string, confidence: float}>
     */
    private function scanGhanaClassifier(UploadedFile $image): array
    {
        $token = trim((string) config('services.food_scan.huggingface_token', ''));
        if ($token === '') {
            return [];
        }

        $model = (string) config(
            'services.food_scan.huggingface_model',
            'Kennethdot/convnext_finetuned_ghanaian_food'
        );

        try {
            $bytes = (string) file_get_contents($image->getRealPath());
            $mime = $image->getMimeType() ?: 'image/jpeg';

            $response = Http::withToken($token)
                ->timeout((int) config('services.food_scan.timeout', 90))
                ->withHeaders(['Content-Type' => $mime])
                ->withBody($bytes, $mime)
                ->post("https://api-inference.huggingface.co/models/{$model}");

            if ($response->status() === 503) {
                sleep(2);
                $response = Http::withToken($token)
                    ->timeout((int) config('services.food_scan.timeout', 90))
                    ->withHeaders(['Content-Type' => $mime])
                    ->withBody($bytes, $mime)
                    ->post("https://api-inference.huggingface.co/models/{$model}");
            }

            if (! $response->successful()) {
                return [];
            }

            $json = $response->json();
            if (! is_array($json)) {
                return [];
            }

            $rows = [];
            foreach ($json as $item) {
                if (! is_array($item)) {
                    continue;
                }
                $label = (string) ($item['label'] ?? '');
                $score = (float) ($item['score'] ?? 0);
                if ($label === '' || $score <= 0) {
                    continue;
                }
                $rows[] = ['name' => $label, 'confidence' => $score];
            }

            usort($rows, fn ($a, $b) => $b['confidence'] <=> $a['confidence']);

            return array_slice($rows, 0, 5);
        } catch (\Throwable) {
            return [];
        }
    }

    /**
     * @return list<array{name: string, confidence: float}>
     */
    private function scanGeminiFlash(UploadedFile $image): array
    {
        $apiKey = trim((string) config('services.food_scan.gemini_api_key', ''));
        if ($apiKey === '') {
            return [];
        }

        $model = (string) config('services.food_scan.gemini_model', 'gemini-2.5-flash');
        $mime = $image->getMimeType() ?: 'image/jpeg';

        try {
            $b64 = base64_encode((string) file_get_contents($image->getRealPath()));

            $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent";

            $response = Http::timeout((int) config('services.food_scan.timeout', 90))
                ->withQueryParameters(['key' => $apiKey])
                ->post($url, [
                    'contents' => [
                        [
                            'parts' => [
                                [
                                    'text' => $this->geminiPrompt(),
                                ],
                                [
                                    'inline_data' => [
                                        'mime_type' => $mime,
                                        'data' => $b64,
                                    ],
                                ],
                            ],
                        ],
                    ],
                    'generationConfig' => [
                        'temperature' => 0.15,
                        'responseMimeType' => 'application/json',
                    ],
                ]);

            if (! $response->successful()) {
                return [];
            }

            $text = data_get($response->json(), 'candidates.0.content.parts.0.text');
            if (! is_string($text) || trim($text) === '') {
                return [];
            }

            $parsed = json_decode($text, true);
            if (! is_array($parsed)) {
                return [];
            }

            $foods = $parsed['foods'] ?? $parsed['detections'] ?? $parsed['items'] ?? [];
            if (! is_array($foods)) {
                return [];
            }

            $rows = [];
            foreach ($foods as $food) {
                if (! is_array($food)) {
                    continue;
                }
                $rows[] = [
                    'name' => (string) ($food['name'] ?? $food['class_name'] ?? ''),
                    'confidence' => (float) ($food['confidence'] ?? $food['score'] ?? 0),
                ];
            }

            return $rows;
        } catch (\Throwable) {
            return [];
        }
    }

    private function geminiPrompt(): string
    {
        $allowed = implode(', ', self::CATALOG_CLASS_NAMES);

        return <<<PROMPT
You identify Ghanaian and West African foods in a meal photo for AkwaabaFit.

If there is no food (people, furniture, packaging without food, empty plate), return JSON only:
{"foods":[]}

Otherwise return JSON only:
{"foods":[{"name":"jollof","confidence":0.9}]}

Rules:
- "name" MUST be one of these exact catalog ids: {$allowed}
- List every distinct food visible on the plate (up to 5). Mixed plates are common (e.g. banku + okro + tilapia, waakye + shito + chicken).
- Prefer Ghanaian dish names over Western substitutes (banku is not dumpling; kenkey is not corn bread; fufu is not mashed potato; waakye is not rice and beans generically).
- confidence is 0-1 how sure you are that item is present.
- Do not invent foods that are not visible.
PROMPT;
    }

    /**
     * @param  list<array{name: string, confidence: float}>  $rows
     * @param  array<string, string>  $aliases
     * @return list<array{class_name: string, display_name: string, confidence: float, source: string}>
     */
    private function normalizeRows(array $rows, array $aliases, string $source): array
    {
        $out = [];
        $seen = [];
        $mergedAliases = array_merge(self::GHANA_LABEL_ALIASES, self::SLM_ALIASES, $aliases);
        $allowed = array_flip(self::CATALOG_CLASS_NAMES);

        foreach ($rows as $row) {
            $raw = trim((string) ($row['name'] ?? ''));
            if ($raw === '') {
                continue;
            }

            $key = Str::lower(preg_replace('/\s+/', ' ', $raw) ?? $raw);
            $className = $mergedAliases[$key] ?? Str::slug($key, '-');

            // Accept exact catalog ids returned by Gemini closed vocabulary.
            if (! isset($allowed[$className]) && isset($allowed[$key])) {
                $className = $key;
            }

            if ($className === '' || ! isset($allowed[$className]) || isset($seen[$className])) {
                continue;
            }

            $confidence = (float) ($row['confidence'] ?? 0);
            if ($confidence <= 0) {
                continue;
            }

            $seen[$className] = true;
            $out[] = [
                'class_name' => $className,
                'display_name' => self::DISPLAY_NAMES[$className] ?? $this->titleCase($className),
                'confidence' => round(min(1.0, max(0.0, $confidence)), 4),
                'source' => $source,
            ];
        }

        usort($out, fn ($a, $b) => $b['confidence'] <=> $a['confidence']);

        return array_slice($out, 0, 5);
    }

    /**
     * @param  array{name: string, confidence: float}  $hfBest
     * @param  list<array{class_name: string, display_name: string, confidence: float, source: string}>  $gemini
     * @return list<array{class_name: string, display_name: string, confidence: float, source: string}>
     */
    private function boostIfAgrees(array $hfBest, array $gemini): array
    {
        $hfKey = Str::lower(trim($hfBest['name']));
        $hfKey = preg_replace('/\s+/', ' ', $hfKey) ?? $hfKey;
        $hfClass = self::GHANA_LABEL_ALIASES[$hfKey] ?? Str::slug($hfKey, '-');

        foreach ($gemini as $i => $item) {
            if ($item['class_name'] === $hfClass) {
                $gemini[$i]['confidence'] = round(min(1.0, $item['confidence'] + 0.08), 4);
                $gemini[$i]['source'] = 'hybrid_agreement';
                usort($gemini, fn ($a, $b) => $b['confidence'] <=> $a['confidence']);

                return $gemini;
            }
        }

        return $gemini;
    }

    private function titleCase(string $className): string
    {
        return Str::title(str_replace('-', ' ', $className));
    }

    /**
     * @param  list<array{class_name: string, display_name: string, confidence: float, source: string}>  $detections
     * @return list<array{class_name: string, display_name: string, confidence: float, source: string}>
     */
    private function applyConfidenceFloor(array $detections): array
    {
        $min = (float) config('services.food_scan.min_detection_confidence', 0.30);

        return array_values(array_filter(
            $detections,
            static fn (array $row): bool => ($row['confidence'] ?? 0) >= $min
        ));
    }
}
