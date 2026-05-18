<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dietitian_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            $table->string('full_name');
            $table->string('specialty')->nullable();
            $table->string('category')->nullable();
            $table->unsignedInteger('hourly_rate')->default(0);
            $table->string('image_url')->nullable();

            $table->string('certificate_path');
            $table->string('status')->default('pending'); // pending|approved|rejected
            $table->text('review_notes')->nullable();

            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->unique('user_id');
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dietitian_applications');
    }
};
