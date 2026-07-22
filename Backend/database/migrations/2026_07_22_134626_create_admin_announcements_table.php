<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_announcements', function (Blueprint $table) {
            $table->id();
            $table->string('title', 120);
            $table->string('body', 500);
            $table->timestamp('sent_at')->nullable()->index();
            $table->unsignedInteger('push_attempted')->default(0);
            $table->unsignedInteger('push_succeeded')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_announcements');
    }
};
