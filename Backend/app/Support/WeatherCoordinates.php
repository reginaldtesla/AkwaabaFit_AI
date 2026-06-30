<?php

namespace App\Support;

use Illuminate\Http\Request;

final class WeatherCoordinates
{
    /**
     * @return array{0: ?float, 1: ?float}
     */
    public static function optionalFromRequest(Request $request): array
    {
        $lat = $request->query('lat');
        $lon = $request->query('lon');

        if (! is_numeric($lat) || ! is_numeric($lon)) {
            return [null, null];
        }

        $latF = (float) $lat;
        $lonF = (float) $lon;

        if ($latF < -90 || $latF > 90 || $lonF < -180 || $lonF > 180) {
            return [null, null];
        }

        return [$latF, $lonF];
    }
}
