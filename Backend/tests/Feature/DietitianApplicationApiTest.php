<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DietitianApplicationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_submit_dietitian_application(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $dob = now()->subYears(30)->toDateString();

        $resp = $this->post('/api/dietetics/application', [
            'full_name' => 'Ama Mensah',
            'date_of_birth' => $dob,
            'age' => 30,
            'phone' => '0244123456',
            'alt_phone' => '0555987654',
            'professional_email' => 'ama.mensah@example.com',
            'ghana_card_number' => 'GHA-123456789-0',
            'residential_address' => '12 Ring Road, Accra',
            'city' => 'Accra',
            'region' => 'Greater Accra',
            'highest_qualification' => 'BSc Nutrition',
            'institution' => 'University of Ghana',
            'years_experience' => 5,
            'license_number' => 'RD-GH-12345',
            'bio' => str_repeat('Experienced registered dietitian serving clients across Ghana. ', 3),
            'specialty' => 'Diabetes care',
            'category' => 'Clinical',
            'hourly_rate' => 150,
            'certificate' => UploadedFile::fake()->create('cert.pdf', 100, 'application/pdf'),
            'ghana_card' => UploadedFile::fake()->create('ghana_card.pdf', 50, 'application/pdf'),
            'profile_photo' => UploadedFile::fake()->create('photo.jpg', 100, 'image/jpeg'),
            'cv' => UploadedFile::fake()->create('cv.pdf', 80, 'application/pdf'),
        ], ['Accept' => 'application/json']);

        $resp->assertCreated()
            ->assertJsonPath('application.status', 'pending')
            ->assertJsonPath('application.full_name', 'Ama Mensah');

        $this->assertDatabaseHas('dietitian_applications', [
            'user_id' => $user->id,
            'ghana_card_number' => 'GHA-123456789-0',
            'professional_email' => 'ama.mensah@example.com',
            'license_number' => 'RD-GH-12345',
            'category' => 'Clinical',
            'status' => 'pending',
        ]);

        $row = \App\Models\DietitianApplication::query()->where('user_id', $user->id)->first();
        $this->assertNotNull($row);
        $this->assertNotNull($row->submitted_at);
        Storage::disk('public')->assertExists($row->certificate_path);
        Storage::disk('public')->assertExists($row->ghana_card_path);
        Storage::disk('public')->assertExists($row->profile_photo_path);
        Storage::disk('public')->assertExists($row->cv_path);

        $resp->assertJsonPath('application.storage_complete', true);
    }

    public function test_pending_application_cannot_be_resubmitted(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = $this->minimalPayload();

        $this->post('/api/dietetics/application', $payload, ['Accept' => 'application/json'])
            ->assertCreated();

        $this->post('/api/dietetics/application', $payload, ['Accept' => 'application/json'])
            ->assertStatus(409);
    }

    private function minimalPayload(): array
    {
        $dob = now()->subYears(28)->toDateString();

        return [
            'full_name' => 'Test Applicant',
            'date_of_birth' => $dob,
            'age' => 28,
            'phone' => '0555123456',
            'alt_phone' => '0244111222',
            'professional_email' => 'applicant@example.com',
            'ghana_card_number' => 'GHA-999888777-1',
            'residential_address' => 'Kumasi',
            'city' => 'Kumasi',
            'region' => 'Ashanti',
            'highest_qualification' => 'MSc',
            'institution' => 'KNUST',
            'years_experience' => 3,
            'license_number' => 'NUT-9988',
            'bio' => str_repeat('Professional nutrition background with clinical placements. ', 3),
            'specialty' => 'Weight management',
            'category' => 'General',
            'hourly_rate' => 120,
            'certificate' => UploadedFile::fake()->create('cert.pdf', 50, 'application/pdf'),
            'ghana_card' => UploadedFile::fake()->create('id.pdf', 50, 'application/pdf'),
            'profile_photo' => UploadedFile::fake()->create('photo.jpg', 100, 'image/jpeg'),
            'cv' => UploadedFile::fake()->create('cv.pdf', 60, 'application/pdf'),
        ];
    }
}
