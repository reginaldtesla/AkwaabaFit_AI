<?php

beforeEach(function () {
    config(['admin.password' => 'staff-secret-123']);
});

test('admin can send a broadcast announcement', function () {
    $this->post('/admin/login', ['password' => 'staff-secret-123'])
        ->assertRedirect(route('admin.dashboard'));

    $this->get('/admin/broadcast')
        ->assertOk()
        ->assertSee('Send to everyone');

    $this->post('/admin/broadcast', [
        'title' => 'Weekend challenge',
        'body' => 'Hit 8,000 steps this weekend and log your meals.',
    ])
        ->assertRedirect(route('admin.broadcast'));

    $this->assertDatabaseHas('admin_announcements', [
        'title' => 'Weekend challenge',
        'body' => 'Hit 8,000 steps this weekend and log your meals.',
    ]);
});

test('broadcast validation requires title and body', function () {
    $this->post('/admin/login', ['password' => 'staff-secret-123']);

    $this->post('/admin/broadcast', [
        'title' => 'Hi',
        'body' => 'Hey',
    ])->assertSessionHasErrors(['title', 'body']);
});
