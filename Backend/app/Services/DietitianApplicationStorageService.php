<?php

namespace App\Services;

use App\Models\DietitianApplication;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Persists nutritionist applications: form fields in MySQL, uploads on the public disk.
 *
 * Run once per environment: php artisan storage:link
 */
class DietitianApplicationStorageService
{
    public function persist(User $user, array $data, array $files, ?DietitianApplication $existing): DietitianApplication
    {
        $baseDir = 'dietitian_applications/'.$user->id;
        $previousPaths = $existing ? $this->filePaths($existing) : [];

        $stored = [
            'certificate_path' => $this->storeUpload($files['certificate'], $baseDir, 'nutrition_cert'),
            'ghana_card_path' => $this->storeUpload($files['ghana_card'], $baseDir, 'ghana_card'),
            'profile_photo_path' => $this->storeUpload($files['profile_photo'], $baseDir, 'profile_photo'),
            'cv_path' => $this->storeUpload($files['cv'], $baseDir, 'cv'),
        ];

        try {
            $application = DB::transaction(function () use ($user, $data, $stored) {
                $profilePhotoPath = $stored['profile_photo_path'];
                $imageUrl = Storage::disk('public')->url($profilePhotoPath);

                $application = DietitianApplication::query()->updateOrCreate(
                    ['user_id' => $user->id],
                    [
                        'full_name' => $data['full_name'],
                        'date_of_birth' => $data['date_of_birth'],
                        'age' => (int) $data['age'],
                        'phone' => $data['phone'],
                        'alt_phone' => $data['alt_phone'],
                        'professional_email' => $data['professional_email'],
                        'ghana_card_number' => $data['ghana_card_number'],
                        'ghana_card_path' => $stored['ghana_card_path'],
                        'residential_address' => $data['residential_address'],
                        'city' => $data['city'],
                        'region' => $data['region'],
                        'highest_qualification' => $data['highest_qualification'],
                        'institution' => $data['institution'],
                        'years_experience' => (int) $data['years_experience'],
                        'license_number' => $data['license_number'],
                        'bio' => $data['bio'],
                        'specialty' => $data['specialty'],
                        'category' => $data['category'],
                        'hourly_rate' => (int) $data['hourly_rate'],
                        'image_url' => $imageUrl,
                        'profile_photo_path' => $profilePhotoPath,
                        'certificate_path' => $stored['certificate_path'],
                        'cv_path' => $stored['cv_path'],
                        'status' => 'pending',
                        'review_notes' => null,
                        'reviewed_at' => null,
                        'submitted_at' => now(),
                    ]
                );

                $application->refresh();

                if (! $this->recordIsComplete($application)) {
                    throw new RuntimeException('Application record incomplete after save.');
                }

                return $application;
            });
        } catch (\Throwable $e) {
            $this->deletePaths(array_values($stored));
            throw $e instanceof RuntimeException ? $e : new RuntimeException($e->getMessage(), 0, $e);
        }

        if ($previousPaths !== []) {
            $this->deletePaths($previousPaths);
        }

        return $application;
    }

    public function recordIsComplete(DietitianApplication $application): bool
    {
        $required = [
            'full_name',
            'date_of_birth',
            'age',
            'phone',
            'alt_phone',
            'professional_email',
            'ghana_card_number',
            'ghana_card_path',
            'residential_address',
            'city',
            'region',
            'highest_qualification',
            'institution',
            'years_experience',
            'license_number',
            'bio',
            'specialty',
            'category',
            'hourly_rate',
            'certificate_path',
            'profile_photo_path',
            'cv_path',
        ];

        foreach ($required as $column) {
            $value = $application->{$column};
            if ($value === null || $value === '') {
                return false;
            }
        }

        foreach ($this->filePaths($application) as $path) {
            if (! $this->fileExists($path)) {
                return false;
            }
        }

        return true;
    }

    /** @return list<string> */
    public function filePaths(DietitianApplication $application): array
    {
        return array_values(array_filter([
            $application->certificate_path,
            $application->ghana_card_path,
            $application->profile_photo_path,
            $application->cv_path,
        ], fn ($p) => is_string($p) && $p !== ''));
    }

    private function storeUpload(UploadedFile $file, string $baseDir, string $prefix): string
    {
        $name = $prefix.'_'.Str::uuid().'.'.$file->getClientOriginalExtension();
        $path = $file->storeAs($baseDir, $name, 'public');

        if ($path === false || ! $this->fileExists($path)) {
            throw new RuntimeException("Failed to store uploaded file: {$prefix}");
        }

        return $path;
    }

    private function fileExists(string $path): bool
    {
        $disk = Storage::disk('public');

        if ($disk->exists($path)) {
            return true;
        }

        $relative = str_starts_with($path, 'public/')
            ? substr($path, strlen('public/'))
            : $path;

        return $relative !== '' && $disk->exists($relative);
    }

    /** @param list<string> $paths */
    private function deletePaths(array $paths): void
    {
        $disk = Storage::disk('public');
        foreach ($paths as $path) {
            if ($path === '') {
                continue;
            }
            $disk->delete($path);
            $relative = str_starts_with($path, 'public/')
                ? substr($path, strlen('public/'))
                : $path;
            if ($relative !== '' && $relative !== $path) {
                $disk->delete($relative);
            }
        }
    }
}
