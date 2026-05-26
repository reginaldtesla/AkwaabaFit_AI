<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * OpenWeatherMap snapshot (cached) for dashboard and Stride activity.
 */
class OpenWeatherService
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
    public function snapshot(): array
    {
        $apiKey = trim((string) config('services.openweather.key', ''));
        $lat = (float) config('services.openweather.default_lat', 5.6037);
        $lon = (float) config('services.openweather.default_lon', -0.1870);
        $fallbackLabel = (string) config('services.openweather.default_label', 'Accra, GH');

        if ($apiKey === '') {
            return $this->emptySnapshot($fallbackLabel);
        }

        $cacheKey = "openweather:{$lat}:{$lon}";

        try {
            return Cache::store('file')->remember($cacheKey, now()->addMinutes(10), function () use ($apiKey, $lat, $lon, $fallbackLabel) {
                return $this->fetch($apiKey, $lat, $lon, $fallbackLabel);
            });
        } catch (\Throwable $e) {
            try {
                return $this->fetch($apiKey, $lat, $lon, $fallbackLabel);
            } catch (\Throwable $e2) {
                return $this->emptySnapshot($fallbackLabel);
            }
        }
    }

      /**
     * @return array{0: float, 1: string, 2: array<string, mixed>}
     */
    public function legacyTuple(): array
    {
        $s = $this->snapshot();

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
    private function fetch(string $apiKey, float $lat, float $lon, string $fallbackLabel): array
    {
        $weather = Http::timeout(6)->get('https://api.openweathermap.org/data/2.5/weather', [
            'lat' => $lat,
            'lon' => $lon,
            'appid' => $apiKey,
            'units' => 'metric',
        ]);

        $air = Http::timeout(6)->get('https://api.openweathermap.org/data/2.5/air_pollution', [
            'lat' => $lat,
            'lon' => $lon,
            'appid' => $apiKey,
        ]);

        $temp = 0.0;
        $label = $fallbackLabel;
        $weatherMain = null;
        $weatherDesc = null;

        if ($weather->ok()) {
            $temp = (float) data_get($weather->json(), 'main.temp', 0.0);
            $name = (string) data_get($weather->json(), 'name', '');
            $country = (string) data_get($weather->json(), 'sys.country', '');
            $label = trim($name.(strlen($country) ? ", {$country}" : '')) ?: $fallbackLabel;
            $weatherMain = data_get($weather->json(), 'weather.0.main');
            $weatherDesc = data_get($weather->json(), 'weather.0.description');
        }

        $aqi = null;
        $pm25 = null;
        $pm10 = null;
        if ($air->ok()) {
            $aqi = data_get($air->json(), 'list.0.main.aqi');
            $pm25 = data_get($air->json(), 'list.0.components.pm2_5');
            $pm10 = data_get($air->json(), 'list.0.components.pm10');
        }

        return [
            'tempCelsius' => $temp,
            'location' => $label,
            'weatherMain' => $weatherMain ? (string) $weatherMain : null,
            'weatherDescription' => $weatherDesc ? (string) $weatherDesc : null,
            'airQualityAqi' => is_numeric($aqi) ? (int) $aqi : null,
            'pm2_5' => is_numeric($pm25) ? round((float) $pm25, 1) : null,
            'pm10' => is_numeric($pm10) ? round((float) $pm10, 1) : null,
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
