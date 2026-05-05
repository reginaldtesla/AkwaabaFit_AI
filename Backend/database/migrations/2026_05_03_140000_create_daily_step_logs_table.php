<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('daily_step_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->integer('step_count')->default(0);
            $table->date('log_date');
            $table->timestamps();
            $table->unique(['user_id', 'log_date']); 
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('daily_step_logs');
    }
};