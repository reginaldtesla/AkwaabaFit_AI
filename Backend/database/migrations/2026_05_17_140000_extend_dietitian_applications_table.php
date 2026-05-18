<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('dietitian_applications', function (Blueprint $table) {
            $table->date('date_of_birth')->nullable()->after('full_name');
            $table->unsignedTinyInteger('age')->nullable()->after('date_of_birth');
            $table->string('phone', 32)->nullable()->after('age');
            $table->string('alt_phone', 32)->nullable()->after('phone');
            $table->string('professional_email')->nullable()->after('alt_phone');
            $table->string('ghana_card_number', 32)->nullable()->after('professional_email');
            $table->string('ghana_card_path')->nullable()->after('ghana_card_number');
            $table->text('residential_address')->nullable()->after('ghana_card_path');
            $table->string('city')->nullable()->after('residential_address');
            $table->string('region')->nullable()->after('city');
            $table->string('highest_qualification')->nullable()->after('region');
            $table->string('institution')->nullable()->after('highest_qualification');
            $table->unsignedTinyInteger('years_experience')->nullable()->after('institution');
            $table->string('license_number')->nullable()->after('years_experience');
            $table->text('bio')->nullable()->after('license_number');
            $table->string('cv_path')->nullable()->after('certificate_path');
            $table->string('profile_photo_path')->nullable()->after('cv_path');
        });
    }

    public function down(): void
    {
        Schema::table('dietitian_applications', function (Blueprint $table) {
            $table->dropColumn([
                'date_of_birth',
                'age',
                'phone',
                'alt_phone',
                'professional_email',
                'ghana_card_number',
                'ghana_card_path',
                'residential_address',
                'city',
                'region',
                'highest_qualification',
                'institution',
                'years_experience',
                'license_number',
                'bio',
                'cv_path',
                'profile_photo_path',
            ]);
        });
    }
};
