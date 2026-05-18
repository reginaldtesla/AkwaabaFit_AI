<?php

namespace App\Http\Controllers;

use App\Models\DietitianApplication;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;

class DietitianApplicationPortalController extends Controller
{
    public function show(Request $request)
    {
        $userId = (int) $request->query('user');
        $user = User::query()->findOrFail($userId);

        $application = DietitianApplication::query()->where('user_id', $user->id)->first();

        return view('dietetics.apply', [
            'user' => $user,
            'application' => $application,
        ]);
    }

    public function submit(Request $request)
    {
        $userId = (int) $request->query('user');
        $user = User::query()->findOrFail($userId);

        $existing = DietitianApplication::query()->where('user_id', $user->id)->first();
        if ($existing && $existing->status === 'pending') {
            return redirect()->back()->with('status', 'Your application is still in review.');
        }

        $data = $request->validate([
            'full_name' => ['required', 'string', 'max:255'],
            'specialty' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'hourly_rate' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'image_url' => ['nullable', 'string', 'max:1000'],
            // max is in KB (20MB). Keep in sync with public/.user.ini.
            'certificate' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:20480'],
        ]);

        /** @var UploadedFile $file */
        $file = $request->file('certificate');
        // Store on the `public` disk so files live under storage/app/public (works with `php artisan storage:link` if you use direct URLs later).
        $path = $file->storeAs(
            'dietitian_certificates',
            'cert_'.$user->id.'_'.Str::uuid().'.'.$file->getClientOriginalExtension(),
            'public',
        );

        DietitianApplication::query()->updateOrCreate(
            ['user_id' => $user->id],
            [
                'full_name' => $data['full_name'],
                'specialty' => $data['specialty'] ?? null,
                'category' => $data['category'] ?? null,
                'hourly_rate' => (int) ($data['hourly_rate'] ?? 0),
                'image_url' => $data['image_url'] ?? null,
                'certificate_path' => $path,
                'status' => 'pending',
                'review_notes' => null,
                'reviewed_at' => null,
            ]
        );

        return redirect()->back()->with('status', 'Submitted. Your application is now in review.');
    }
}
