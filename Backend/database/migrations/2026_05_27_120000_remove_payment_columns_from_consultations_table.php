<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('consultations', function (Blueprint $table) {
            $table->dropUnique(['paystack_reference']);
        });

        Schema::table('consultations', function (Blueprint $table) {
            $table->dropColumn([
                'payment_status',
                'paystack_reference',
                'amount',
                'currency',
            ]);
        });
    }

    public function down(): void
    {
        Schema::table('consultations', function (Blueprint $table) {
            $table->string('payment_status')->default('pending');
            $table->string('paystack_reference')->nullable();
            $table->unsignedInteger('amount')->default(0);
            $table->string('currency', 10)->default('GHS');
        });

        Schema::table('consultations', function (Blueprint $table) {
            $table->unique('paystack_reference');
        });
    }
};
