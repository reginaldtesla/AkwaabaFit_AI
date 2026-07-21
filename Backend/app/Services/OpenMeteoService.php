<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Free weather + air quality via Open-Meteo (no API key).
 *
 * @see https://open-meteo.com/
 */
class OpenMeteoService
{
    /**
     * @return array{
     *   tempCelsius: float,
     *   location: string,
     *   weatherMain: ?string,
     *   weatherDescription: ?string,
     *   airQualityAqi: ?int,
     *   pm2_5: ?float,
     *   pm10: ?float
     * }
     */
    public function snapshot(?float $lat = null, ?float $lon = null): array
    {
        $hasClientCoords = $lat !== null && $lon !== null;
        $lat = $lat ?? (float) config('services.weather.default_lat', 5.6037);
        $lon = $lon ?? (float) config('services.weather.default_lon', -0.1870);
        $fallbackLabel = (string) config('services.weather.default_label', 'Accra, GH');
        $unavailableLabel = 'Enable location for local weather';

        $lat = max(-90.0, min(90.0, $lat));
        $lon = max(-180.0, min(180.0, $lon));

        // Without the user's coordinates, do not present default Accra weather as local truth.
        if (! $hasClientCoords) {
            return $this->emptySnapshot($unavailableLabel);
        }

        $cacheKey = sprintf('openmeteo:%.3f:%.3f', $lat, $lon);
        $ttlMinutes = (int) config('services.weather.cache_minutes', 15);

        try {
            return Cache::store('file')->remember(
                $cacheKey,
                now()->addMinutes(max(5, $ttlMinutes)),
                fn () => $this->fetch($lat, $lon, $fallbackLabel)
            );
        } catch (\Throwable) {
            try {
                return $this->fetch($lat, $lon, $fallbackLabel);
            } catch (\Throwable) {
                return $this->emptySnapshot($unavailableLabel);
            }
        }
    }

    /**
     * @return array{0: float, 1: string, 2: array<string, mixed>}
     */
    public function legacyTuple(?float $lat = null, ?float $lon = null): array
    {
        $s = $this->snapshot($lat, $lon);

        return [
            $s['tempCelsius'],
            $s['location'],
            [
                'aqi' => $s['airQualityAqi'],
                'pm2_5' => $s['pm2_5'],
                'pm10' => $s['pm10'],
                'weatherMain' => $s['weatherMain'],
                'weatherDescription' => $s['weatherDescription'],
            ],
        ];
    }

    /**
     * @return array{
     *   tempCelsius: float,
     *   location: string,
     *   weatherMain: ?string,
     *   weatherDescription: ?string,
     *   airQualityAqi: ?int,
     *   pm2_5: ?float,
     *   pm10: ?float
     * }
     */
    private function fetch(float $lat, float $lon, string $fallbackLabel): array
    {
        $forecast = Http::timeout(8)->get('https://api.open-meteo.com/v1/forecast', [
            'latitude' => $lat,
            'longitude' => $lon,
            'current' => 'temperature_2m,weather_code',
            'timezone' => 'auto',
        ]);

        $air = Http::timeout(8)->get('https://air-quality-api.open-meteo.com/v1/air-quality', [
            'latitude' => $lat,
            'longitude' => $lon,
            'current' => 'us_aqi,pm2_5,pm10',
            'timezone' => 'auto',
        ]);

        $temp = 0.0;
        $code = null;
        if ($forecast->ok()) {
            $temp = (float) data_get($forecast->json(), 'current.temperature_2m', 0.0);
            $rawCode = data_get($forecast->json(), 'current.weather_code');
            $code = is_numeric($rawCode) ? (int) $rawCode : null;
        }

        $aqi = null;
        $pm25 = null;
        $pm10 = null;
        if ($air->ok()) {
            $rawAqi = data_get($air->json(), 'current.us_aqi');
            $aqi = is_numeric($rawAqi) ? (int) round((float) $rawAqi) : null;
            $rawPm25 = data_get($air->json(), 'current.pm2_5');
            $rawPm10 = data_get($air->json(), 'current.pm10');
            $pm25 = is_numeric($rawPm25) ? round((float) $rawPm25, 1) : null;
            $pm10 = is_numeric($rawPm10) ? round((float) $rawPm10, 1) : null;
        }

        $weatherMain = $code !== null ? $this->wmoToWeatherMain($code) : null;
        $weatherDesc = $code !== null ? $this->wmoToDescription($code) : null;

        return [
            'tempCelsius' => round($temp, 1),
            'location' => $this->reverseGeocodeLabel($lat, $lon, $fallbackLabel),
            'weatherMain' => $weatherMain,
            'weatherDescription' => $weatherDesc,
            'airQualityAqi' => $aqi,
            'pm2_5' => $pm25,
            'pm10' => $pm10,
        ];
    }

    private function reverseGeocodeLabel(float $lat, float $lon, string $fallback): string
    {
        try {
            $resp = Http::timeout(8)
                ->withHeaders([
                    'User-Agent' => 'AkwaabaFit/1.0 (weather; contact: support@akwaabafit.com)',
                ])
                ->get('https://nominatim.openstreetmap.org/reverse', [
                    'lat' => $lat,
                    'lon' => $lon,
                    'format' => 'json',
                    'addressdetails' => 1,
                    'accept-language' => 'en',
                    'zoom' => 10,
                ]);

            if (! $resp->ok()) {
                return $this->coordinateLabel($lat, $lon) ?? $fallback;
            }

            $json = $resp->json();
            if (! is_array($json)) {
                return $this->coordinateLabel($lat, $lon) ?? $fallback;
            }

            $address = $json['address'] ?? null;
            if (is_array($address)) {
                $city = $this->firstNonEmpty([
                    $address['city'] ?? null,
                    $address['town'] ?? null,
                    $address['village'] ?? null,
                    $address['municipality'] ?? null,
                    $address['suburb'] ?? null,
                    $address['county'] ?? null,
                ]);
                $region = $this->firstNonEmpty([
                    $address['state'] ?? null,
                    $address['region'] ?? null,
                ]);
                $country = trim((string) ($address['country'] ?? ''));

                $parts = array_values(array_filter([
                    $city,
                    ($region !== null && $region !== $city) ? $region : null,
                    $country !== '' ? $country : null,
                ], static fn ($v) => $v !== null && $v !== ''));

                if ($parts !== []) {
                    return implode(', ', array_slice($parts, 0, 3));
                }
            }

            $display = trim((string) ($json['display_name'] ?? ''));
            if ($display !== '') {
                $chunks = array_map('trim', explode(',', $display));
                if (count($chunks) >= 2) {
                    return $chunks[0].', '.$chunks[count($chunks) - 1];
                }

                return $display;
            }
        } catch (\Throwable) {
            // fall through
        }

        return $this->coordinateLabel($lat, $lon) ?? $fallback;
    }

    /**
     * @param  list<mixed>  $values
     */
    private function firstNonEmpty(array $values): ?string
    {
        foreach ($values as $value) {
            $trimmed = trim((string) ($value ?? ''));
            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        return null;
    }

    private function coordinateLabel(float $lat, float $lon): string
    {
        $latH = $lat >= 0 ? 'N' : 'S';
        $lonH = $lon >= 0 ? 'E' : 'W';

        return sprintf(
            '%.2f°%s, %.2f°%s',
            abs($lat),
            $latH,
            abs($lon),
            $lonH
        );
    }

    private function wmoToWeatherMain(int $code): string
    {
        return match (true) {
            $code === 0 => 'Clear',
            in_array($code, [1, 2, 3], true) => 'Clouds',
            in_array($code, [45, 48], true) => 'Mist',
            in_array($code, [51, 53, 55, 56, 57], true) => 'Drizzle',
            in_array($code, [61, 63, 65, 66, 67, 80, 81, 82], true) => 'Rain',
            in_array($code, [71, 73, 75, 77, 85, 86], true) => 'Snow',
            in_array($code, [95, 96, 99], true) => 'Thunderstorm',
            default => 'Clouds',
        };
    }

    private function wmoToDescription(int $code): string
    {
        return match ($code) {
            0 => 'clear sky',
            1 => 'mainly clear',
            2 => 'partly cloudy',
            3 => 'overcast',
            45 => 'fog',
            48 => 'depositing rime fog',
            51, 53, 55 => 'drizzle',
            56, 57 => 'freezing drizzle',
            61, 63, 65 => 'rain',
            66, 67 => 'freezing rain',
            71, 73, 75 => 'snow',
            77 => 'snow grains',
            80, 81, 82 => 'rain showers',
            85, 86 => 'snow showers',
            95 => 'thunderstorm',
            96, 99 => 'thunderstorm with hail',
            default => 'cloudy',
        };
    }

    /**
     * @return array{
     *   tempCelsius: float,
     *   location: string,
     *   weatherMain: ?string,
     *   weatherDescription: ?string,
     *   airQualityAqi: ?int,
     *   pm2_5: ?float,
     *   pm10: ?float
     * }
     */
    private function emptySnapshot(string $fallbackLabel): array
    {
        return [
            'tempCelsius' => 0.0,
            'location' => $fallbackLabel,
            'weatherMain' => null,
            'weatherDescription' => null,
            'airQualityAqi' => null,
            'pm2_5' => null,
            'pm10' => null,
        ];
    }
}
