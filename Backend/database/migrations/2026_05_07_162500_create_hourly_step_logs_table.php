<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hourly_step_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('log_date');
            $table->unsignedTinyInteger('hour'); // 0-23
            $table->unsignedInteger('step_count')->default(0);
            $table->timestamps();

            $table->unique(['user_id', 'log_date', 'hour']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('hourly_step_logs');
    }
};

