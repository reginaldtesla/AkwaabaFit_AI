<?php

namespace App\Notifications;

use Illuminate\Contracts\Auth\CanResetPassword;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class ApiPasswordResetNotification extends Notification
{
    public function __construct(public string $token) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        /** @var CanResetPassword $notifiable */
        $email = $notifiable->getEmailForPasswordReset();

        return (new MailMessage)
            ->subject('Reset your AkwaabaFit password')
            ->line('You asked to reset your password. Use this code in the AkwaabaFit app — it expires in 60 minutes.')
            ->line('Your account email: **'.$email.'**')
            ->line('Reset code: **'.$this->token.'**')
            ->line('If you did not request this, you can ignore this email.');
    }
}
