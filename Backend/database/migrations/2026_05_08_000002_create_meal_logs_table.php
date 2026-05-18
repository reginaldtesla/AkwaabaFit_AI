<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('meal_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('eaten_at')->index();
            $table->string('meal_type')->nullable(); // Breakfast/Lunch/Dinner/Snacks
            $table->string('name');
            $table->unsignedInteger('calories')->default(0);
            $table->unsignedInteger('protein_g')->nullable();
            $table->unsignedInteger('carbs_g')->nullable();
            $table->unsignedInteger('fat_g')->nullable();
            $table->string('safety_status')->nullable(); // safe/watch/alert
            $table->string('insight_message')->nullable();
            $table->string('image_url')->nullable();
            $table->string('source')->default('scan'); // scan/manual
            $table->json('meta')->nullable(); // additional AI fields
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('meal_logs');
    }
};
