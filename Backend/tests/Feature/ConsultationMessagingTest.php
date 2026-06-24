<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\ConsultationMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConsultationMessagingTest extends TestCase
{
    use RefreshDatabase;

    private function makeActiveConsultation(User $client, User $advisor): Consultation
    {
        return Consultation::create([
            'user_id' => $client->id,
            'dietician_name' => 'Dr Test',
            'advisor_user_id' => $advisor->id,
            'paid_at' => now(),
            'session_expires_at' => now()->addHour(),
            'scheduled_time' => now(),
        ]);
    }

    public function test_client_messages_index_includes_pagination_and_peer_typing_keys(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        Sanctum::actingAs($client);

        $response = $this->getJson("/api/consultations/{$c->id}/messages");

        $response->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonStructure([
                'messages',
                'pagination' => ['has_more', 'oldest_id', 'newest_id'],
                'peer_typing',
                'session',
            ]);
    }

    public function test_client_fetch_marks_professional_messages_as_read(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        $msg = ConsultationMessage::create([
            'consultation_id' => $c->id,
            'sender' => 'professional',
            'body' => 'Hello from advisor',
        ]);
        $this->assertNull($msg->fresh()->read_at);

        Sanctum::actingAs($client);
        $this->getJson("/api/consultations/{$c->id}/messages")->assertOk();

        $this->assertNotNull($msg->fresh()->read_at);
    }

    public function test_client_post_message_creates_activity_log_and_persists_message(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        Sanctum::actingAs($client);

        $response = $this->postJson("/api/consultations/{$c->id}/messages", [
            'body' => 'Question about meals',
        ]);

        $response->assertCreated()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('message.sender', 'user');

        $this->assertDatabaseHas('consultation_messages', [
            'consultation_id' => $c->id,
            'sender' => 'user',
            'body' => 'Question about meals',
        ]);

        $this->assertDatabaseHas('consultation_activity_logs', [
            'consultation_id' => $c->id,
            'actor_user_id' => $client->id,
            'action' => 'message_sent',
        ]);
    }

    public function test_message_pagination_with_limit_and_before_id(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        foreach (range(1, 5) as $i) {
            ConsultationMessage::create([
                'consultation_id' => $c->id,
                'sender' => 'user',
                'body' => "m{$i}",
            ]);
        }

        Sanctum::actingAs($client);

        $first = $this->getJson("/api/consultations/{$c->id}/messages?limit=2")->assertOk();
        $first->assertJsonPath('pagination.has_more', true);
        $this->assertCount(2, $first->json('messages'));

        $oldest = $first->json('pagination.oldest_id');
        $this->assertNotNull($oldest);

        $second = $this->getJson("/api/consultations/{$c->id}/messages?limit=2&before_id={$oldest}")->assertOk();
        $this->assertCount(2, $second->json('messages'));
    }

    public function test_advisor_can_send_typing_ping_during_active_session(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        Sanctum::actingAs($advisor);

        $this->postJson("/api/advisor/consultations/{$c->id}/typing")->assertOk()
            ->assertJsonPath('status', 'success');
    }

    public function test_client_can_send_typing_ping_during_active_session(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        Sanctum::actingAs($client);

        $this->postJson("/api/consultations/{$c->id}/typing")->assertOk()
            ->assertJsonPath('status', 'success');
    }

    public function test_messages_delta_after_id_zero_returns_empty_messages(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        ConsultationMessage::create([
            'consultation_id' => $c->id,
            'sender' => 'user',
            'body' => 'hello',
        ]);

        Sanctum::actingAs($client);

        $this->getJson("/api/consultations/{$c->id}/messages/delta?after_id=0")
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonCount(0, 'messages');
    }

    public function test_messages_delta_returns_only_newer_rows(): void
    {
        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        $a = ConsultationMessage::create([
            'consultation_id' => $c->id,
            'sender' => 'user',
            'body' => 'first',
        ]);
        ConsultationMessage::create([
            'consultation_id' => $c->id,
            'sender' => 'user',
            'body' => 'second',
        ]);

        Sanctum::actingAs($client);

        $this->getJson("/api/consultations/{$c->id}/messages/delta?after_id={$a->id}")
            ->assertOk()
            ->assertJsonCount(1, 'messages')
            ->assertJsonPath('messages.0.body', 'second');
    }

    public function test_message_blocked_when_blocklist_matches(): void
    {
        config(['consultation_messages.blocked_substrings' => ['forbiddenphrase']]);

        $client = User::factory()->create();
        $advisor = User::factory()->create(['is_nutrition_advisor' => true]);
        $c = $this->makeActiveConsultation($client, $advisor);

        Sanctum::actingAs($client);

        $this->postJson("/api/consultations/{$c->id}/messages", [
            'body' => 'Hello forbiddenphrase world',
        ])->assertStatus(422);
    }
}
