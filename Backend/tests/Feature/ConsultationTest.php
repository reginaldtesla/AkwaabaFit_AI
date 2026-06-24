<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConsultationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_book_consultation(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/consultations/book', [
            'dietician_name' => 'Dr. Akwaaba',
            'scheduled_time' => now()->addDays(2)->toDateTimeString(),
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonStructure(['status', 'message', 'data' => ['id', 'dietician_name']]);

        $this->assertDatabaseHas('consultations', [
            'user_id' => $user->id,
            'dietician_name' => 'Dr. Akwaaba',
        ]);
    }
}
