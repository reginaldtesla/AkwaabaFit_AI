<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminDashboardTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['admin.password' => 'staff-secret-123']);
    }

    public function test_admin_panel_is_hidden_when_password_not_configured(): void
    {
        config(['admin.password' => '']);

        $this->get('/admin')->assertNotFound();
    }

    public function test_staff_can_sign_in_and_view_dashboard(): void
    {
        User::factory()->create([
            'name' => 'Ama',
            'email' => 'ama@example.com',
            'profile_completed' => true,
        ]);

        $this->get('/admin')->assertOk()->assertSee('Sign in to view app usage');

        $this->post('/admin/login', ['password' => 'wrong'])
            ->assertSessionHasErrors('password');

        $this->post('/admin/login', ['password' => 'staff-secret-123'])
            ->assertRedirect(route('admin.dashboard'));

        $this->get('/admin/dashboard')
            ->assertOk()
            ->assertSee('App usage')
            ->assertSee('Total users')
            ->assertSee('ama@example.com');
    }

    public function test_authenticated_api_request_updates_last_seen_at(): void
    {
        $user = User::factory()->create([
            'last_seen_at' => null,
        ]);

        $token = $user->createToken('phone')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/user')
            ->assertOk();

        $user->refresh();
        $this->assertNotNull($user->last_seen_at);
        $this->assertTrue($user->last_seen_at->greaterThan(now()->subMinute()));
    }
}
