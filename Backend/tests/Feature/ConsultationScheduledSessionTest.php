<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConsultationScheduledSessionTest extends TestCase
{
    use RefreshDatabase;

    public function test_scheduled_session_is_waiting_before_start_time(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $start = now()->addHours(3);

        $c = Consultation::create([
            'user_id' => $client->id,
            'dietician_name' => 'Dr Test',
            'advisor_user_id' => $advisor->id,
            'paid_at' => now(),
            'scheduled_time' => $start,
            'session_expires_at' => $start->copy()->addHours(2),
        ]);

        Sanctum::actingAs($client);

        $this->getJson("/api/consultations/{$c->id}/messages")
            ->assertOk()
            ->assertJsonPath('session.phase', 'waiting')
            ->assertJsonPath('session.active', false);

        $this->postJson("/api/consultations/{$c->id}/messages", [
            'body' => 'Hello early',
        ])->assertStatus(402);
    }

    public function test_scheduled_session_is_live_after_start_time(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $start = now()->subMinutes(5);

        $c = Consultation::create([
            'user_id' => $client->id,
            'dietician_name' => 'Dr Test',
            'advisor_user_id' => $advisor->id,
            'paid_at' => now()->subHour(),
            'scheduled_time' => $start,
            'session_expires_at' => $start->copy()->addHours(2),
        ]);

        Sanctum::actingAs($client);

        $this->getJson("/api/consultations/{$c->id}/messages")
            ->assertOk()
            ->assertJsonPath('session.phase', 'live')
            ->assertJsonPath('session.active', true);
    }
}
