<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DieteticsReviewUnlockController extends Controller
{
    public function show(): View
    {
        return view('admin.dietetics.unlock');
    }

    public function unlock(Request $request): RedirectResponse
    {
        $expected = (string) config('services.dietetics_review.key', '');
        if ($expected === '') {
            return redirect()->back()->withErrors(['key' => 'Review portal is not configured on the server (missing DIETETICS_REVIEW_KEY).']);
        }

        $data = $request->validate([
            'key' => ['required', 'string'],
        ]);

        if (! hash_equals($expected, $data['key'])) {
            return redirect()->back()->withErrors(['key' => 'That key is incorrect. Copy it exactly from Backend .env (DIETETICS_REVIEW_KEY).']);
        }

        $request->session()->regenerate();
        $request->session()->put('dietetics_review_unlocked', true);

        return redirect()->route('dietetics.review.applications');
    }

    public function lock(Request $request): RedirectResponse
    {
        $request->session()->forget('dietetics_review_unlocked');

        return redirect()->route('dietetics.review.unlock')->with('status', 'Review portal locked on this browser.');
    }
}
