<?php

namespace Tests\Unit;

use App\Support\LandingLinks;
use Tests\TestCase;

class LandingLinksTest extends TestCase
{
    public function test_support_mailto_includes_recipient_subject_and_body(): void
    {
        config([
            'landing.support_email' => 'help@example.com',
            'landing.support_email_subject' => 'Hello team',
            'landing.support_email_body' => "Line one\nLine two",
        ]);

        $url = LandingLinks::supportMailto();

        $this->assertStringStartsWith('mailto:help@example.com?', $url);
        $this->assertStringContainsString('subject=Hello%20team', $url);
        $this->assertStringContainsString('body=Line%20one%0ALine%20two', $url);
    }
}
