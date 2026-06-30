<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('food_nutrition_items', function (Blueprint $table) {
            $table->string('preparation_type', 30)->default('standard')->after('class_name');
        });

        Schema::table('food_nutrition_items', function (Blueprint $table) {
            $table->dropUnique(['class_name']);
            $table->unique(['class_name', 'preparation_type']);
        });
    }

    public function down(): void
    {
        Schema::table('food_nutrition_items', function (Blueprint $table) {
            $table->dropUnique(['class_name', 'preparation_type']);
            $table->unique(['class_name']);
            $table->dropColumn('preparation_type');
        });
    }
};
