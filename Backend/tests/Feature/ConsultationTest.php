<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConsultationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_book_consultation(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->postJson('/api/consultations/book', [
            'dietician_name' => 'Dr. Akwaaba',
            'scheduled_time' => now()->addDays(2)->toDateTimeString(),
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure(['status', 'message', 'data' => ['paystack_reference']]);

        $this->assertDatabaseHas('consultations', [
            'user_id' => $user->id,
            'dietician_name' => 'Dr. Akwaaba',
            'payment_status' => 'pending',
        ]);
    }

    public function test_paystack_webhook_updates_payment_status(): void
    {
        $user = User::factory()->create();
        $consultation = Consultation::create([
            'user_id' => $user->id,
            'dietician_name' => 'Dr. Akwaaba',
            'paystack_reference' => 'TEST_REF_123',
            'payment_status' => 'pending',
        ]);

        $payload = [
            'event' => 'charge.success',
            'data' => [
                'reference' => 'TEST_REF_123',
                'status' => 'success',
            ],
        ];

        $secret = 'test_secret';
        config(['services.paystack.secret_key' => $secret]);
        $signature = hash_hmac('sha512', json_encode($payload), $secret);

        $response = $this->withHeaders([
            'x-paystack-signature' => $signature,
        ])->postJson('/api/webhook/paystack', $payload);

        $response->assertStatus(200);

        $this->assertDatabaseHas('consultations', [
            'id' => $consultation->id,
            'payment_status' => 'paid',
        ]);
    }
}