<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminSession
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! self::adminEnabled()) {
            abort(404);
        }

        if ($request->session()->get(config('admin.session_key')) !== true) {
            return redirect()->route('admin.login');
        }

        return $next($request);
    }

    public static function adminEnabled(): bool
    {
        $password = (string) config('admin.password', '');

        return $password !== '';
    }
}
