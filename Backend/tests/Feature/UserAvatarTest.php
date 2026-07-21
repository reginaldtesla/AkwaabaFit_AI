<?php

namespace Tests\Feature;

use App\Support\UserAvatar;
use Tests\TestCase;

class UserAvatarTest extends TestCase
{
    public function test_returns_gender_fallbacks_when_avatar_is_missing(): void
    {
        $this->assertSame('https://i.pravatar.cc/150?img=12', UserAvatar::url(null, 'male'));
        $this->assertSame('https://i.pravatar.cc/150?img=47', UserAvatar::url('', 'female'));
        $this->assertSame('https://i.pravatar.cc/150?img=5', UserAvatar::url(null, null));
    }

    public function test_keeps_absolute_avatar_urls(): void
    {
        $url = 'https://cdn.example.com/a.jpg';
        $this->assertSame($url, UserAvatar::url($url, 'male'));
    }

    public function test_absolutizes_relative_storage_paths(): void
    {
        $resolved = UserAvatar::url('/storage/avatars/1/photo.jpg', 'male');
        $this->assertStringContainsString('/storage/avatars/1/photo.jpg', $resolved);
        $this->assertStringStartsWith('http', $resolved);
    }
}
