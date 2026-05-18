<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateProfileRequest;
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

        // Set profile_completed to true if core health fields are provided
        if (
            isset($data['age']) &&
            isset($data['gender']) &&
            isset($data['height']) &&
            isset($data['weight'])
        ) {
            $data['profile_completed'] = true;
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
        $url = Storage::disk('public')->url($path);

        $user->update(['avatar_url' => $url]);

        return response()->json([
            'status' => 'success',
            'avatarUrl' => $url,
            'user' => $user,
        ]);
    }
}
