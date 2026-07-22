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
        'avocado',
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
        'avocado' => 'avocado',
        'avocado slice' => 'avocado',
        'sliced avocado' => 'avocado',
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
        'avocado' => 'Avocado',
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

    private bool $geminiUnavailable = false;

    /**
     * @return array{
     *   provider: string,
     *   strategy: string,
     *   detections: list<array{class_name: string, display_name: string, confidence: float, source: string}>
     * }
     */
    public function scan(UploadedFile $image): array
    {
        $this->geminiUnavailable = false;
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
            'strategy' => $this->geminiUnavailable ? 'provider_unavailable' : 'none',
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

        // Legacy api-inference.huggingface.co is decommissioned; use the HF Inference router.
        $base = rtrim((string) config(
            'services.food_scan.huggingface_inference_url',
            'https://router.huggingface.co/hf-inference/models'
        ), '/');

        try {
            $bytes = (string) file_get_contents($image->getRealPath());
            $mime = $image->getMimeType() ?: 'image/jpeg';
            $url = "{$base}/{$model}";

            $response = Http::withToken($token)
                ->timeout((int) config('services.food_scan.timeout', 90))
                ->withHeaders([
                    'Content-Type' => $mime,
                    'Accept' => 'application/json',
                ])
                ->withBody($bytes, $mime)
                ->post($url);

            // Cold start / model loading.
            if ($response->status() === 503) {
                sleep(2);
                $response = Http::withToken($token)
                    ->timeout((int) config('services.food_scan.timeout', 90))
                    ->withHeaders([
                        'Content-Type' => $mime,
                        'Accept' => 'application/json',
                    ])
                    ->withBody($bytes, $mime)
                    ->post($url);
            }

            if (! $response->successful()) {
                report(new \RuntimeException(
                    'Ghana food classifier HTTP '.$response->status().': '.Str::limit($response->body(), 300)
                ));

                return [];
            }

            $json = $response->json();
            if (! is_array($json)) {
                return [];
            }

            // Some responses wrap predictions: { "predictions": [...] } or nested lists.
            if (isset($json[0]) && is_array($json[0]) && isset($json[0][0]) && is_array($json[0][0])) {
                $json = $json[0];
            }
            if (isset($json['predictions']) && is_array($json['predictions'])) {
                $json = $json['predictions'];
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
        } catch (\Throwable $e) {
            report($e);

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
            $this->geminiUnavailable = true;

            return [];
        }

        $mime = $image->getMimeType() ?: 'image/jpeg';

        try {
            $b64 = base64_encode((string) file_get_contents($image->getRealPath()));
            $payload = [
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
            ];

            $sawQuota = false;
            foreach ($this->geminiModels() as $model) {
                $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent";

                $response = Http::timeout((int) config('services.food_scan.timeout', 90))
                    ->withQueryParameters(['key' => $apiKey])
                    ->post($url, $payload);

                if ($response->status() === 429 || $response->status() === 403) {
                    $sawQuota = true;

                    continue;
                }

                if (! $response->successful()) {
                    continue;
                }

                $text = data_get($response->json(), 'candidates.0.content.parts.0.text');
                if (! is_string($text) || trim($text) === '') {
                    continue;
                }

                $parsed = json_decode($text, true);
                if (! is_array($parsed)) {
                    continue;
                }

                $foods = $parsed['foods'] ?? $parsed['detections'] ?? $parsed['items'] ?? [];
                if (! is_array($foods)) {
                    continue;
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
            }

            $this->geminiUnavailable = $sawQuota;

            return [];
        } catch (\Throwable) {
            $this->geminiUnavailable = true;

            return [];
        }
    }

    /**
     * @return list<string>
     */
    private function geminiModels(): array
    {
        $primary = trim((string) config('services.food_scan.gemini_model', 'gemini-2.0-flash'));
        $fallbacks = [
            'gemini-2.0-flash',
            'gemini-2.0-flash-lite',
            'gemini-flash-latest',
            'gemini-2.5-flash',
        ];

        return array_values(array_unique(array_filter([$primary, ...$fallbacks])));
    }

    private function geminiPrompt(): string
    {
        $allowed = implode(', ', self::CATALOG_CLASS_NAMES);

        return <<<PROMPT
You identify Ghanaian and West African foods in a meal photo for AkwaabaFit.

If there is no food (people, furniture, packaging without food, empty plate), return JSON only:
{"foods":[]}

Otherwise return JSON only:
{"foods":[{"name":"plantain","confidence":0.9},{"name":"kontomire","confidence":0.85}]}

Rules:
- "name" MUST be one of these exact catalog ids: {$allowed}
- List every distinct food visible on the plate (up to 5). Mixed plates are common
  (e.g. plantain + kontomire, banku + okro + tilapia, waakye + shito + chicken, ampesi + stew).
- Boiled or fried yellow plantain fingers → "plantain". Leafy green stew (kontomire / palava) → "kontomire".
- Prefer Ghanaian dish names over Western substitutes (banku is not dumpling; kenkey is not corn bread;
  fufu is not mashed potato; kontomire is not generic spinach; plantain is not banana).
- Dim indoor chop-bar photos still count as food when a plate of Ghanaian food is visible.
- confidence is 0-1 how sure you are that item is present.
- Do not invent foods that are not visible. Never return an empty foods list when a plated meal is clearly visible.
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
            $className = $this->resolveClassName($key, $mergedAliases, $allowed);
            if ($className === null || isset($seen[$className])) {
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
     * @param  array<string, string>  $aliases
     * @param  array<string, int>  $allowed
     */
    private function resolveClassName(string $key, array $aliases, array $allowed): ?string
    {
        if (isset($aliases[$key]) && isset($allowed[$aliases[$key]])) {
            return $aliases[$key];
        }
        if (isset($allowed[$key])) {
            return $key;
        }

        $slug = Str::slug($key, '-');
        if (isset($allowed[$slug])) {
            return $slug;
        }

        // Substring fallbacks for HF/Gemini free-text that miss exact aliases.
        $needles = [
            'kontomire' => 'kontomire',
            'palava' => 'kontomire',
            'palaver' => 'kontomire',
            'plaintain' => 'plantain',
            'plantain' => 'plantain',
            'kelewele' => 'kelewele',
            'tatale' => 'kelewele',
            'ampesi' => 'yam',
            'jollof' => 'jollof',
            'waakye' => 'waakye',
            'wakye' => 'waakye',
            'banku' => 'banku',
            'kenkey' => 'kenkey',
            'fufu' => 'fufu',
            'okro' => 'okro',
            'okra' => 'okro',
            'groundnut' => 'groundnut-soup',
            'palmnut' => 'palmnut-soup',
            'palm nut' => 'palmnut-soup',
            'shito' => 'shito',
            'tilapia' => 'tilapia',
            'koose' => 'koose',
            'kose' => 'koose',
            'red red' => 'beans',
            'gobe' => 'beans',
        ];

        foreach ($needles as $needle => $className) {
            if (str_contains($key, $needle) && isset($allowed[$className])) {
                return $className;
            }
        }

        return null;
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
