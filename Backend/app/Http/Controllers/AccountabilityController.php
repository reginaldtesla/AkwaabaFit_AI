<?php

namespace App\Http\Controllers;

use App\Models\AccountabilityPartner;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class AccountabilityController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user->accountability_code) {
            $user->update(['accountability_code' => $this->generateCode()]);
            $user->refresh();
        }

        $partner = AccountabilityPartner::query()
            ->where('user_id', $user->id)
            ->where('status', 'accepted')
            ->with('partner:id,name,username')
            ->first();

        $partnerSummary = null;
        if ($partner?->partner) {
            $partnerSummary = [
                'name' => $partner->partner->name,
                'username' => $partner->partner->username,
            ];
        }

        return response()->json([
            'status' => 'success',
            'code' => $user->accountability_code,
            'partner' => $partnerSummary,
        ]);
    }

    public function link(Request $request): JsonResponse
    {
        $data = $request->validate([
            'partner_code' => ['required', 'string', 'min:6', 'max:8'],
        ]);

        $user = $request->user();
        $code = Str::upper(trim($data['partner_code']));

        if ($code === Str::upper((string) $user->accountability_code)) {
            return response()->json([
                'status' => 'error',
                'message' => 'You cannot link to your own code.',
            ], 422);
        }

        $partner = User::query()->where('accountability_code', $code)->first();
        if (! $partner) {
            return response()->json([
                'status' => 'error',
                'message' => 'No user found with that accountability code.',
            ], 404);
        }

        AccountabilityPartner::query()->updateOrCreate(
            ['user_id' => $user->id, 'partner_user_id' => $partner->id],
            ['status' => 'accepted'],
        );
        AccountabilityPartner::query()->updateOrCreate(
            ['user_id' => $partner->id, 'partner_user_id' => $user->id],
            ['status' => 'accepted'],
        );

        return response()->json([
            'status' => 'success',
            'partner' => [
                'name' => $partner->name,
                'username' => $partner->username,
            ],
        ]);
    }

    public function unlink(Request $request): JsonResponse
    {
        $user = $request->user();
        $row = AccountabilityPartner::query()
            ->where('user_id', $user->id)
            ->where('status', 'accepted')
            ->first();

        if ($row) {
            AccountabilityPartner::query()
                ->where(function ($q) use ($user, $row) {
                    $q->where('user_id', $user->id)->where('partner_user_id', $row->partner_user_id);
                })
                ->orWhere(function ($q) use ($user, $row) {
                    $q->where('user_id', $row->partner_user_id)->where('partner_user_id', $user->id);
                })
                ->delete();
        }

        return response()->json(['status' => 'success']);
    }

    private function generateCode(): string
    {
        do {
            $code = Str::upper(Str::random(6));
        } while (User::query()->where('accountability_code', $code)->exists());

        return $code;
    }
}
