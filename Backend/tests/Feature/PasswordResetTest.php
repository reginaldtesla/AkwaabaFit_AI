<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\ApiPasswordResetNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_sends_notification_when_user_exists(): void
    {
        Notification::fake();

        $user = User::factory()->create([
            'username' => 'resetme',
            'email' => 'reset@example.com',
        ]);

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'reset@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJsonFragment(['message' => 'If an account exists for that email, we sent reset instructions.']);

        Notification::assertSentTo($user, ApiPasswordResetNotification::class);
    }

    public function test_forgot_password_does_not_reveal_unknown_accounts(): void
    {
        Notification::fake();

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'unknown-person@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJsonFragment(['message' => 'If an account exists for that email, we sent reset instructions.']);

        Notification::assertNothingSent();
    }

    public function test_reset_password_updates_password_and_allows_login(): void
    {
        Notification::fake();

        $user = User::factory()->create([
            'username' => 'pwchanger',
            'email' => 'pw@example.com',
            'password' => bcrypt('oldpassword123'),
        ]);

        $this->postJson('/api/forgot-password', ['email' => 'pw@example.com']);

        $plainToken = '';
        Notification::assertSentTo(
            $user,
            ApiPasswordResetNotification::class,
            function (ApiPasswordResetNotification $notification) use (&$plainToken) {
                $plainToken = $notification->token;

                return true;
            }
        );
        $this->assertNotSame('', $plainToken);

        $reset = $this->postJson('/api/reset-password', [
            'email' => 'pw@example.com',
            'token' => $plainToken,
            'password' => 'brandnewpass456',
            'password_confirmation' => 'brandnewpass456',
        ]);

        $reset->assertStatus(200)
            ->assertJsonFragment(['message' => 'Password updated. You can sign in with your new password.']);

        $user->refresh();
        $this->assertTrue(Hash::check('brandnewpass456', $user->password));

        $this->postJson('/api/login', [
            'login' => 'pwchanger',
            'password' => 'brandnewpass456',
            'device_name' => 'test client',
        ])->assertStatus(200)->assertJsonStructure(['token']);
    }
}
