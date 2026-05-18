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
    if ($consultation->payment_status !== 'paid') {
      return null;
    }

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

  /** When payment succeeds: window ends at start + duration (start may be in the future). */
  public function paidSessionExpiresAt(Consultation $consultation): CarbonInterface
  {
    $start = $this->startsAtForPayment($consultation);

    return $start->copy()->addHours(self::SESSION_HOURS);
  }

  public function startsAtForPayment(Consultation $consultation): CarbonInterface
  {
    if ($consultation->scheduled_time !== null) {
      return $consultation->scheduled_time->copy();
    }

    return now();
  }

  public function phase(Consultation $consultation): string
  {
    if ($consultation->payment_status !== 'paid') {
      return 'unpaid';
    }

    $start = $this->startsAt($consultation);
    $end = $this->endsAt($consultation);
    if ($start === null || $end === null) {
      return 'unpaid';
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
      'payment_status' => $consultation->payment_status,
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
