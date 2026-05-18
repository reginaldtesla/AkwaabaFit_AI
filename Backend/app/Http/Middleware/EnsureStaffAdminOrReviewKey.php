<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Staff accounts (is_staff_admin) or legacy shared-key unlock / header / query key.
 */
class EnsureStaffAdminOrReviewKey
{
    public function handle(Request $request, Closure $next): Response
    {
        if (Auth::check() && Auth::user()->is_staff_admin) {
            return $next($request);
        }

        $allowSharedKey = (bool) config('services.dietetics_review.allow_shared_key', true);
        $expected = (string) config('services.dietetics_review.key', '');

        if ($allowSharedKey && $expected !== '') {
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
                ->withErrors(['key' => 'Missing or wrong review key.']);
        }

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Unauthorized.'], 401);
        }

        return redirect()
            ->route('staff.admin.login')
            ->withErrors(['email' => 'Staff admin sign-in is required (or set DIETETICS_ALLOW_SHARED_KEY=true with DIETETICS_REVIEW_KEY).']);
    }
}
