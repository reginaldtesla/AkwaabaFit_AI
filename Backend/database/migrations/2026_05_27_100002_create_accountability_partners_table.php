<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('accountability_partners', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('partner_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 20)->default('accepted');
            $table->timestamps();

            $table->unique(['user_id', 'partner_user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('accountability_partners');
    }
};
