<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('food_nutrition_items', function (Blueprint $table) {
            $table->id();
            $table->string('class_name')->unique();
            $table->string('display_name');
            $table->unsignedInteger('calories')->default(0);
            $table->unsignedInteger('protein_g')->default(0);
            $table->unsignedInteger('carbs_g')->default(0);
            $table->unsignedInteger('fat_g')->default(0);
            $table->decimal('iron_mg', 6, 2)->default(0);
            $table->unsignedInteger('folate_mcg')->default(0);
            $table->string('safety_status')->default('safe');
            $table->string('insight_message')->nullable();
            $table->string('portion_label')->default('1 serving');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('food_nutrition_items');
    }
};
