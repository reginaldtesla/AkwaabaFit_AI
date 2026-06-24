<?php

namespace App\Services;

use App\Models\Consultation;
use Carbon\Carbon;
use Carbon\CarbonInterface;

class ConsultationSessionService
{
    public const SESSION_HOURS = 2;

    public function startsAt(Consultation $consultation): ?CarbonInterface
    {
        if ($consultation->scheduled_time !== null) {
            return $consultation->scheduled_time->copy();
        }

        return ($consultation->paid_at ?? $consultation->created_at)?->copy();
    }

    public function endsAt(Consultation $consultation): ?CarbonInterface
    {
        $start = $this->startsAt($consultation);
        if ($start === null) {
            return null;
        }

        if ($consultation->session_expires_at !== null) {
            return $consultation->session_expires_at->copy();
        }

        return $start->copy()->addHours(self::SESSION_HOURS);
    }

    public function sessionExpiresAt(Consultation $consultation): CarbonInterface
    {
        $start = $this->sessionStartAnchor($consultation);

        return $start->copy()->addHours(self::SESSION_HOURS);
    }

    public function sessionStartAnchor(Consultation $consultation): CarbonInterface
    {
        if ($consultation->scheduled_time !== null) {
            return $consultation->scheduled_time->copy();
        }

        return now();
    }

    public function phase(Consultation $consultation): string
    {
        $start = $this->startsAt($consultation);
        $end = $this->endsAt($consultation);
        if ($start === null || $end === null) {
            return 'ended';
        }

        $now = now();
        if ($now->lt($start)) {
            return 'waiting';
        }
        if ($now->lt($end)) {
            return 'live';
        }

        return 'ended';
    }

    public function isLive(Consultation $consultation): bool
    {
        return $this->phase($consultation) === 'live';
    }

    public function secondsUntilStart(Consultation $consultation): int
    {
        if ($this->phase($consultation) !== 'waiting') {
            return 0;
        }

        $start = $this->startsAt($consultation);
        if ($start === null) {
            return 0;
        }

        return max(0, now()->diffInSeconds($start, false));
    }

    public function secondsRemaining(Consultation $consultation): int
    {
        if ($this->phase($consultation) !== 'live') {
            return 0;
        }

        $end = $this->endsAt($consultation);
        if ($end === null) {
            return 0;
        }

        return max(0, now()->diffInSeconds($end, false));
    }

    public function toArray(Consultation $consultation): array
    {
        return [
            'scheduled_at' => optional($consultation->scheduled_time)->toIso8601String(),
            'starts_at' => optional($this->startsAt($consultation))->toIso8601String(),
            'expires_at' => optional($this->endsAt($consultation))->toIso8601String(),
            'active' => $this->isLive($consultation),
            'phase' => $this->phase($consultation),
            'seconds_until_start' => $this->secondsUntilStart($consultation),
            'seconds_remaining' => $this->secondsRemaining($consultation),
            'server_now' => now()->toIso8601String(),
        ];
    }
}
