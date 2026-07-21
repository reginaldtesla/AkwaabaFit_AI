<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateProfileRequest;
use App\Support\HealthProfileOptions;
use App\Support\LeaderboardCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'user' => $user,
        ]);
    }

    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();

        if (
            isset($data['age'], $data['gender'], $data['height'], $data['weight'], $data['goal'], $data['activity_level'])
        ) {
            $data['profile_completed'] = true;
        }

        if (! isset($data['water_goal_ml']) && isset($data['weight'])) {
            $data['water_goal_ml'] = HealthProfileOptions::defaultWaterGoalMl((int) $data['weight']);
        }

        if (
            isset($data['activity_context'], $data['activity_level'])
            && ! isset($data['step_goal'])
        ) {
            $data['step_goal'] = HealthProfileOptions::ghanaStepGoalForContext(
                (string) $data['activity_context'],
                (string) $data['activity_level'],
            );
        }

        if (! $user->accountability_code && ($data['profile_completed'] ?? false)) {
            $data['accountability_code'] = strtoupper(substr(bin2hex(random_bytes(4)), 0, 6));
        }

        if (array_key_exists('is_public_on_leaderboard', $data)) {
            LeaderboardCache::forgetCurrent();
        }

        $user->update($data);

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully',
            'user' => $user,
        ]);
    }

    public function uploadAvatar(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'avatar' => ['required', 'image', 'max:5120'], // 5MB
        ]);

        /** @var UploadedFile $file */
        $file = $data['avatar'];
        $path = $file->storePublicly("avatars/{$user->id}", 'public');
        $stored = Storage::disk('public')->url($path);
        $url = str_starts_with($stored, 'http://') || str_starts_with($stored, 'https://')
            ? $stored
            : url($stored);

        $user->update(['avatar_url' => $url]);

        return response()->json([
            'status' => 'success',
            'avatarUrl' => $url,
            'user' => $user,
        ]);
    }
}
