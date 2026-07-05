<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Middleware\EnsureAdminSession;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AuthController extends Controller
{
    public function showLogin(Request $request): View|RedirectResponse
    {
        if (! EnsureAdminSession::adminEnabled()) {
            abort(404);
        }

        if ($request->session()->get(config('admin.session_key')) === true) {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.login');
    }

    public function login(Request $request): RedirectResponse
    {
        if (! EnsureAdminSession::adminEnabled()) {
            abort(404);
        }

        $data = $request->validate([
            'password' => ['required', 'string', 'max:255'],
        ]);

        $expected = (string) config('admin.password', '');
        if (! hash_equals($expected, $data['password'])) {
            return back()
                ->withInput($request->except('password'))
                ->withErrors(['password' => 'Incorrect password.']);
        }

        $request->session()->regenerate();
        $request->session()->put(config('admin.session_key'), true);

        return redirect()->route('admin.dashboard');
    }

    public function logout(Request $request): RedirectResponse
    {
        $request->session()->forget(config('admin.session_key'));
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
