<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireReviewKey
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = (string) config('services.dietetics_review.key', '');
        if ($expected === '') {
            return response('Review portal not configured.', 503);
        }

        if ($request->session()->get('dietetics_review_unlocked') === true) {
            return $next($request);
        }

        $provided = (string) ($request->header('X-Review-Key') ?? $request->query('key', ''));
        if (hash_equals($expected, $provided)) {
            return $next($request);
        }

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Unauthorized.'], 401);
        }

        return redirect()
            ->route('dietetics.review.unlock')
            ->withErrors(['key' => 'Missing or wrong review key. Paste DIETETICS_REVIEW_KEY on the unlock page (do not share that page publicly).']);
    }
}
