<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->json('health_conditions')->nullable()->after('goal');
            $table->string('eating_pattern', 40)->default('Regular')->after('health_conditions');
            $table->string('life_stage', 40)->default('General adult')->after('eating_pattern');
            $table->string('meal_source_preference', 40)->default('Mixed')->after('life_stage');
            $table->string('activity_context', 40)->default('Mixed')->after('meal_source_preference');
            $table->unsignedSmallInteger('water_goal_ml')->nullable()->after('activity_context');
            $table->boolean('meal_reminders_enabled')->default(true)->after('water_goal_ml');
            $table->string('accountability_code', 8)->nullable()->unique()->after('meal_reminders_enabled');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'health_conditions',
                'eating_pattern',
                'life_stage',
                'meal_source_preference',
                'activity_context',
                'water_goal_ml',
                'meal_reminders_enabled',
                'accountability_code',
            ]);
        });
    }
};
