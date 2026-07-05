<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RecordUserLastSeen
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $user = $request->user();
        if ($user === null) {
            return $response;
        }

        $lastSeen = $user->last_seen_at;
        if ($lastSeen !== null && $lastSeen->greaterThan(now()->subMinute())) {
            return $response;
        }

        $user->forceFill(['last_seen_at' => now()])->save();

        return $response;
    }
}
