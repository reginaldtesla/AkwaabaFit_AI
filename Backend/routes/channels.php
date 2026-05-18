<?php

use App\Models\Consultation;
use Illuminate\Support\Facades\Broadcast;

Broadcast::routes(['middleware' => ['auth:sanctum']]);

Broadcast::channel('App.Models.User.{id}', function ($user, string $id) {
    return (int) $user->id === (int) $id;
});

Broadcast::channel('consultation.{consultationId}', function ($user, string $consultationId) {
    $consultation = Consultation::query()->find($consultationId);
    if (! $consultation) {
        return false;
    }
    if ((int) $consultation->user_id === (int) $user->id) {
        return ['id' => $user->id, 'name' => $user->name];
    }
    if ($user->is_nutrition_advisor && (int) $consultation->advisor_user_id === (int) $user->id) {
        return ['id' => $user->id, 'name' => $user->name];
    }

    return false;
});
