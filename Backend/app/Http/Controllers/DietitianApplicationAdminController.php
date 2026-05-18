<?php

namespace App\Http\Controllers;

use App\Models\DietitianApplication;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class DietitianApplicationAdminController extends Controller
{
    /**
     * Stream certificate for reviewers (avoids Apache /storage symlink + 403 on many installs).
     * Files are stored on the default disk under paths like public/dietitian_certificates/...
     */
    public function downloadCertificate(DietitianApplication $application): StreamedResponse
    {
        return $this->downloadDocument($application, 'certificate');
    }

    public function downloadDocument(DietitianApplication $application, string $type): StreamedResponse
    {
        $path = match ($type) {
            'certificate' => $application->certificate_path,
            'ghana_card' => $application->ghana_card_path,
            'cv' => $application->cv_path,
            'profile_photo' => $application->profile_photo_path,
            default => null,
        };

        if (! is_string($path) || $path === '') {
            abort(404);
        }

        $local = Storage::disk('local');
        if ($local->exists($path)) {
            return $local->response($path, basename($path), ['Cache-Control' => 'private, max-age=0']);
        }

        $onPublicDisk = str_starts_with($path, 'public/')
            ? substr($path, strlen('public/'))
            : $path;
        $public = Storage::disk('public');
        if ($onPublicDisk !== '' && $public->exists($onPublicDisk)) {
            return $public->response($onPublicDisk, basename($onPublicDisk), ['Cache-Control' => 'private, max-age=0']);
        }

        abort(404, 'Document not found on server.');
    }

    public function index(Request $request)
    {
        $status = $request->query('status');
        $q = DietitianApplication::query()->with('user')->orderByDesc('created_at');
        if (is_string($status) && $status !== '') {
            $q->where('status', $status);
        }
        $items = $q->paginate(30)->withQueryString();

        return view('admin.dietetics.applications', [
            'items' => $items,
            'status' => $status,
        ]);
    }

    public function approve(DietitianApplication $application, Request $request)
    {
        $data = $request->validate([
            'rating' => ['required', 'numeric', 'min:1', 'max:5'],
            'listed_hourly_rate' => ['required', 'integer', 'min:1', 'max:100000'],
            'review_notes' => ['nullable', 'string', 'max:2000'],
        ]);

        $application->user?->update(['is_nutrition_advisor' => true]);
        $application->update([
            'status' => 'approved',
            'rating' => round((float) $data['rating'], 1),
            'listed_hourly_rate' => (int) $data['listed_hourly_rate'],
            'review_notes' => $data['review_notes'] ?? null,
            'reviewed_at' => now(),
        ]);

        return redirect()->back()->with('status', 'Approved and listed in the app.');
    }

    public function reject(DietitianApplication $application, Request $request)
    {
        $application->user?->update(['is_nutrition_advisor' => false]);
        $application->update([
            'status' => 'rejected',
            'review_notes' => $request->input('review_notes'),
            'reviewed_at' => now(),
        ]);

        return redirect()->back()->with('status', 'Rejected.');
    }
}
