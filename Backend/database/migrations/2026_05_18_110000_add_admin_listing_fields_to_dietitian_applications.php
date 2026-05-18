<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('dietitian_applications', function (Blueprint $table) {
            $table->decimal('rating', 2, 1)->nullable()->after('hourly_rate');
            $table->unsignedInteger('listed_hourly_rate')->nullable()->after('rating');
        });

        \Illuminate\Support\Facades\DB::table('dietitian_applications')
            ->where('status', 'approved')
            ->whereNull('listed_hourly_rate')
            ->update([
                'listed_hourly_rate' => \Illuminate\Support\Facades\DB::raw('hourly_rate'),
                'rating' => 5.0,
            ]);
    }

    public function down(): void
    {
        Schema::table('dietitian_applications', function (Blueprint $table) {
            $table->dropColumn(['rating', 'listed_hourly_rate']);
        });
    }
};
