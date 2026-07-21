<?php

namespace App\Support;

/**
 * Open-Meteo returns US AQI (0–500), not a 1–5 European-style index.
 */
final class AirQualityThresholds
{
    /** Unhealthy for Sensitive Groups and above. */
    public const int PoorUsAqi = 100;

    public static function isPoorUsAqi(?int $aqi): bool
    {
        return $aqi !== null && $aqi >= self::PoorUsAqi;
    }
}
