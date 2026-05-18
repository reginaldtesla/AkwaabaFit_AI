<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register()
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Test User',
            'username' => 'testuser',
            'phone' => '+233 24 555 0192',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure(['user', 'token']);

        $this->assertDatabaseHas('users', ['email' => 'test@example.com', 'username' => 'testuser']);
    }

    public function test_user_can_login()
    {
        $user = User::factory()->create([
            'username' => 'logintester',
            'phone' => '2332000111222',
            'password' => bcrypt($password = 'password123'),
        ]);

        $response = $this->postJson('/api/login', [
            'login' => 'logintester',
            'password' => $password,
            'device_name' => 'testing',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['user', 'token']);

        $response = $this->postJson('/api/login', [
            'login' => '+233 20 00111222',
            'password' => $password,
            'device_name' => 'testing',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['user', 'token']);
    }

    public function test_protected_user_route_requires_auth()
    {
        $response = $this->getJson('/api/user');
        $response->assertStatus(401);
    }
}
