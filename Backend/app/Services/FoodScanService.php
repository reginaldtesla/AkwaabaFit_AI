<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Hybrid Ghana food scan:
 * 1) Kennethdot ConvNeXt (Hugging Face) — Ghana-trained classifier
 * 2) Gemini Flash (Google AI Studio free tier) — fallback for low confidence / mixed plates
 */
class FoodScanService
{
    /** Maps HF Ghana model labels → nutrition catalog slugs. */
    private const GHANA_LABEL_ALIASES = [
        'jollof rice ghana' => 'jollof',
        'jollof rice' => 'jollof',
        'jollof' => 'jollof',
        'banku ghana' => 'banku',
        'banku' => 'banku',
        'fufu ghana' => 'fufu',
        'fufu' => 'fufu',
        'kenkey ghana' => 'kenkey',
        'fante kenkey' => 'kenkey',
        'kenkey' => 'kenkey',
        'kelewele ghana' => 'kelewele',
        'kelewele' => 'kelewele',
        'waakye' => 'waakye',
        'kokonte' => 'kokonte',
        'konkonte' => 'kokonte',
        'koose ghana' => 'koose',
        'koose' => 'koose',
        'red red ghana' => 'beans',
        'red red' => 'beans',
        'roasted plaintain ghana' => 'plantain',
        'roasted plantain ghana' => 'plantain',
        'plantain' => 'plantain',
        'kontomire stew ghana' => 'kontomire',
        'kontomire stew' => 'kontomire',
        'yam porridge ghana' => 'yam',
        'yam' => 'yam',
        'gari soakings' => 'rice',
        'plain rice' => 'rice',
        'rice' => 'rice',
        'tatale ghana' => 'kelewele',
        'tatale' => 'kelewele',
        'omotuo ghana' => 'rice',
        'okro stew ghana' => 'okro',
        'groundnut soup ghana' => 'groundnut-soup',
        'palmnut soup ghana' => 'palmnut-soup',
        'ebunubunu ghana' => 'ebunubunu',
        'apapransa ghana' => 'apapransa',
        'tubaani ghana' => 'tubaani',
        'kyinkyinga ghana' => 'kyinkyinga',
        'gobe ghana' => 'beans',
        'gobƐ ghana' => 'beans',
        'zaafi ghana' => 'fufu',
        'fried plantain' => 'plantain',
        'egg' => 'egg-pepper',
        'beans' => 'beans',
        'chicken' => 'chicken',
        'meat' => 'meat',
    ];

    private const SLM_ALIASES = [
        'jollof rice' => 'jollof',
        'jollof' => 'jollof',
        'banku and tilapia' => 'banku',
        'banku' => 'banku',
        'fufu' => 'fufu',
        'waakye' => 'waakye',
        'kenkey' => 'kenkey',
        'kelewele' => 'kelewele',
        'plantain' => 'plantain',
        'fried plantain' => 'plantain',
        'boiled egg' => 'egg-pepper',
        'egg-pepper' => 'egg-pepper',
        'hausa koko' => 'hausa-koko',
        'kokonte' => 'kokonte',
        'koose' => 'koose',
        'nkate cake' => 'nkate-cake',
        'plain rice' => 'rice',
        'rice' => 'rice',
        'yam' => 'yam',
        'beans' => 'beans',
        'red red' => 'beans',
        'kontomire' => 'kontomire',
        'bread' => 'bread',
        'burger' => 'burger',
        'pizza' => 'pizza',
        'pasta' => 'pasta',
        'salad' => 'salad',
        'chicken' => 'chicken',
        'meat' => 'meat',
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
        $hfThreshold = (float) config('services.food_scan.hf_confidence_threshold', 0.65);
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
            throw new RuntimeException('HUGGINGFACE_API_TOKEN is not configured for Ghana food classification.');
        }

        $model = (string) config(
            'services.food_scan.huggingface_model',
            'Kennethdot/convnext_finetuned_ghanaian_food'
        );

        $bytes = (string) file_get_contents($image->getRealPath());
        $mime = $image->getMimeType() ?: 'image/jpeg';

        $response = Http::withToken($token)
            ->timeout((int) config('services.food_scan.timeout', 90))
            ->withHeaders(['Content-Type' => $mime])
            ->withBody($bytes, $mime)
            ->post("https://api-inference.huggingface.co/models/{$model}");

        if ($response->status() === 503) {
            // Model cold-start; one retry after brief wait hint in body.
            sleep(2);
            $response = Http::withToken($token)
                ->timeout((int) config('services.food_scan.timeout', 90))
                ->withHeaders(['Content-Type' => $mime])
                ->withBody($bytes, $mime)
                ->post("https://api-inference.huggingface.co/models/{$model}");
        }

        if (! $response->successful()) {
            throw new RuntimeException('Ghana classifier error: '.$response->body());
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
    }

    /**
     * @return list<array{name: string, confidence: float}>
     */
    private function scanGeminiFlash(UploadedFile $image): array
    {
        $apiKey = trim((string) config('services.food_scan.gemini_api_key', ''));
        if ($apiKey === '') {
            throw new RuntimeException('GEMINI_API_KEY is not configured for food scan fallback.');
        }

        $model = (string) config('services.food_scan.gemini_model', 'gemini-2.5-flash');
        $mime = $image->getMimeType() ?: 'image/jpeg';
        $b64 = base64_encode((string) file_get_contents($image->getRealPath()));

        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent";

        $response = Http::timeout((int) config('services.food_scan.timeout', 90))
            ->withQueryParameters(['key' => $apiKey])
            ->post($url, [
                'contents' => [
                    [
                        'parts' => [
                            [
                                'text' => 'Identify Ghanaian and West African foods visible in this image. '
                                    .'If there is no food, or only non-food objects (people, furniture, packaging without food, empty plate), '
                                    .'return JSON only: {"foods":[]}. '
                                    .'Otherwise return JSON only: {"foods":[{"name":"jollof","confidence":0.9}]} '
                                    .'Use short English names (banku, fufu, waakye, kenkey, kelewele, kontomire, red red). '
                                    .'confidence 0-1 reflects how sure you are it is food. Up to 5 items.',
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
                    'temperature' => 0.2,
                    'responseMimeType' => 'application/json',
                ],
            ]);

        if (! $response->successful()) {
            throw new RuntimeException('Gemini food scan error: '.$response->body());
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

        foreach ($rows as $row) {
            $raw = trim((string) ($row['name'] ?? ''));
            if ($raw === '') {
                continue;
            }

            $key = Str::lower(preg_replace('/\s+/', ' ', $raw) ?? $raw);
            $className = $aliases[$key] ?? Str::slug($key, '-');
            if ($className === '' || isset($seen[$className])) {
                continue;
            }

            $confidence = (float) ($row['confidence'] ?? 0);
            if ($confidence <= 0) {
                continue;
            }

            $seen[$className] = true;
            $out[] = [
                'class_name' => $className,
                'display_name' => $this->titleCase($className),
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
