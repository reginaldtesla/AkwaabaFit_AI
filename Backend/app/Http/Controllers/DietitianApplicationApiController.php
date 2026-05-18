<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreDietitianApplicationRequest;
use App\Models\DietitianApplication;
use App\Services\DietitianApplicationStorageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class DietitianApplicationApiController extends Controller
{
    public function __construct(
        private readonly DietitianApplicationStorageService $storage,
    ) {}

    public function show(Request $request): JsonResponse
    {
        $application = DietitianApplication::query()
            ->where('user_id', $request->user()->id)
            ->first();

        if (! $application) {
            return response()->json([
                'status' => 'success',
                'application' => null,
            ]);
        }

        return response()->json([
            'status' => 'success',
            'application' => $this->applicationPayload($application),
        ]);
    }

    public function store(StoreDietitianApplicationRequest $request): JsonResponse
    {
        $user = $request->user();
        $existing = DietitianApplication::query()->where('user_id', $user->id)->first();

        if ($existing && $existing->status === 'pending') {
            return response()->json([
                'status' => 'error',
                'message' => 'Your application is already in review.',
                'application' => $this->applicationPayload($existing),
            ], 409);
        }

        if ($existing && $existing->status === 'approved') {
            return response()->json([
                'status' => 'error',
                'message' => 'You are already an approved nutrition professional.',
                'application' => $this->applicationPayload($existing),
            ], 409);
        }

        $data = $request->validated();

        try {
            $application = $this->storage->persist(
                $user,
                $data,
                [
                    'certificate' => $request->file('certificate'),
                    'ghana_card' => $request->file('ghana_card'),
                    'profile_photo' => $request->file('profile_photo'),
                    'cv' => $request->file('cv'),
                ],
                $existing,
            );

        } catch (RuntimeException $e) {
            report($e);

            return response()->json([
                'status' => 'error',
                'message' => 'We could not save your application safely. Please try again.',
            ], 500);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Application saved. Our team will review your documents.',
            'application' => $this->applicationPayload($application->fresh()),
        ], 201);
    }

    private function applicationPayload(DietitianApplication $application): array
    {
        $filesOk = $this->storage->recordIsComplete($application);

        return [
            'id' => $application->id,
            'full_name' => $application->full_name,
            'date_of_birth' => optional($application->date_of_birth)->toDateString(),
            'age' => $application->age,
            'phone' => $application->phone,
            'alt_phone' => $application->alt_phone,
            'professional_email' => $application->professional_email,
            'ghana_card_number' => $application->ghana_card_number,
            'residential_address' => $application->residential_address,
            'city' => $application->city,
            'region' => $application->region,
            'highest_qualification' => $application->highest_qualification,
            'institution' => $application->institution,
            'years_experience' => $application->years_experience,
            'license_number' => $application->license_number,
            'bio' => $application->bio,
            'specialty' => $application->specialty,
            'category' => $application->category,
            'hourly_rate' => (int) $application->hourly_rate,
            'image_url' => $application->image_url,
            'status' => $application->status,
            'review_notes' => $application->review_notes,
            'submitted_at' => optional($application->submitted_at ?? $application->updated_at)->toIso8601String(),
            'reviewed_at' => optional($application->reviewed_at)->toIso8601String(),
            'storage_complete' => $filesOk,
            'has_certificate' => filled($application->certificate_path),
            'has_ghana_card' => filled($application->ghana_card_path),
            'has_cv' => filled($application->cv_path),
            'has_profile_photo' => filled($application->profile_photo_path),
        ];
    }
}
