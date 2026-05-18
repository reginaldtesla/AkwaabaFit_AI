<?php

namespace Tests\Feature;

use App\Models\DietitianApplication;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DietitianListingTest extends TestCase
{
    use RefreshDatabase;

    public function test_approved_dietitian_listing_uses_photo_rating_and_admin_rate(): void
    {
        $advisor = User::factory()->create();
        $client = User::factory()->create();

        $photoPath = 'dietitian_applications/'.$advisor->id.'/profile_photo_test.jpg';

        DietitianApplication::query()->create([
            'user_id' => $advisor->id,
            'full_name' => 'Dr Ama Kofi',
            'specialty' => 'Diabetes care',
            'category' => 'Clinical',
            'hourly_rate' => 80,
            'listed_hourly_rate' => 150,
            'rating' => 4.8,
            'image_url' => '/storage/'.$photoPath,
            'profile_photo_path' => $photoPath,
            'certificate_path' => 'dietitian_applications/'.$advisor->id.'/cert.pdf',
            'status' => 'approved',
            'reviewed_at' => now(),
        ]);

        Sanctum::actingAs($client);

        $this->getJson('/api/dietitians')
            ->assertOk()
            ->assertJsonPath('dietitians.0.name', 'Dr Ama Kofi')
            ->assertJsonPath('dietitians.0.rating', 4.8)
            ->assertJsonPath('dietitians.0.hourlyRate', 150)
            ->assertJsonPath('dietitians.0.advisorUserId', $advisor->id);
    }
}
