<?php

namespace Tests\Feature;

use App\Models\DailyStepLog;
use App\Models\MealLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class DashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_fetch_dashboard_data(): void
    {
        $user = User::factory()->create([
            'name' => 'Kwame',
            'activity_level' => 'Moderately active',
            'weight' => 70,
            'gender' => 'Male',
            'goal' => 'Maintain weight',
            'workout_time_preference' => 'Morning',
            'workout_days_per_week' => 3,
        ]);

        DailyStepLog::create([
            'user_id' => $user->id,
            'step_count' => 5000,
            'log_date' => now()->toDateString(),
        ]);

        $this->fakeOpenMeteo();

        $response = $this->actingAs($user)->getJson('/api/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('userName', 'Kwame')
            ->assertJsonPath('avatarUrl', 'https://i.pravatar.cc/150?img=12')
            ->assertJsonPath('currentSteps', 5000)
            ->assertJsonPath('stepGoal', 10000)
            ->assertJsonStructure([
                'dailyCaloriesTarget',
                'macros' => ['proteinG', 'carbsG', 'fatG'],
                'macrosTarget' => ['proteinG', 'carbsG', 'fatG'],
                'workoutPlan' => ['preferredTime', 'daysPerWeek', 'suggested'],
            ])
            ->assertJsonStructure([
                'location',
                'alertTitle',
                'alertMessage',
                'calories',
                'activeMinutes',
            ]);
    }

    public function test_dashboard_uses_custom_daily_calories_target_when_set(): void
    {
        $user = User::factory()->create([
            'name' => 'Ama',
            'activity_level' => 'Moderately active',
            'weight' => 70,
            'gender' => 'Female',
            'goal' => 'Maintain weight',
            'daily_calories_target' => 2618,
        ]);

        $this->fakeOpenMeteo(temp: 22.0, weatherCode: 0, aqi: 1);

        $response = $this->actingAs($user)->getJson('/api/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('dailyCaloriesTarget', 2618)
            ->assertJsonStructure([
                'macros' => ['proteinG', 'carbsG', 'fatG'],
                'macrosTarget' => ['proteinG', 'carbsG', 'fatG'],
            ]);
    }

    public function test_dashboard_macros_reflect_meals_logged_today(): void
    {
        $user = User::factory()->create([
            'activity_level' => 'Moderately active',
            'weight' => 70,
            'gender' => 'Male',
            'goal' => 'Maintain weight',
        ]);

        MealLog::factory()->create([
            'user_id' => $user->id,
            'eaten_at' => now(),
            'calories' => 400,
            'protein_g' => 30,
            'carbs_g' => 45,
            'fat_g' => 12,
        ]);
        MealLog::factory()->create([
            'user_id' => $user->id,
            'eaten_at' => now(),
            'calories' => 300,
            'protein_g' => null,
            'carbs_g' => 20,
            'fat_g' => 8,
        ]);

        $this->fakeOpenMeteo(temp: 22.0, weatherCode: 0, aqi: 1);

        $response = $this->actingAs($user)->getJson('/api/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('consumedKcal', 700)
            ->assertJsonPath('macrosEstimated', true);

        $pk = (int) $response->json('macros.proteinG');
        $ck = (int) $response->json('macros.carbsG');
        $fk = (int) $response->json('macros.fatG');
        $macroKcal = ($pk * 4) + ($ck * 4) + ($fk * 9);
        $this->assertSame(700, $macroKcal);
        $this->assertGreaterThan(0, $pk * $ck * $fk);
    }

    public function test_dashboard_estimates_macros_when_meals_have_calories_only(): void
    {
        $user = User::factory()->create([
            'activity_level' => 'Moderately active',
            'weight' => 70,
            'gender' => 'Male',
            'goal' => 'Maintain weight',
        ]);

        MealLog::factory()->create([
            'user_id' => $user->id,
            'eaten_at' => now(),
            'calories' => 1928,
            'protein_g' => null,
            'carbs_g' => null,
            'fat_g' => null,
        ]);

        $this->fakeOpenMeteo(temp: 22.0, weatherCode: 0, aqi: 1);

        $response = $this->actingAs($user)->getJson('/api/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('consumedKcal', 1928)
            ->assertJsonPath('macrosEstimated', true);

        $totalGrams = (int) $response->json('macros.proteinG')
            + (int) $response->json('macros.carbsG')
            + (int) $response->json('macros.fatG');
        $this->assertGreaterThan(0, $totalGrams);
    }

    private function fakeOpenMeteo(
        float $temp = 29.4,
        int $weatherCode = 45,
        int $aqi = 4,
    ): void {
        Http::fake([
            'api.open-meteo.com/*' => Http::response([
                'current' => [
                    'temperature_2m' => $temp,
                    'weather_code' => $weatherCode,
                ],
            ], 200),
            'air-quality-api.open-meteo.com/*' => Http::response([
                'current' => [
                    'us_aqi' => $aqi,
                    'pm2_5' => 55.2,
                    'pm10' => 140.7,
                ],
            ], 200),
            'geocoding-api.open-meteo.com/*' => Http::response([
                'results' => [
                    ['name' => 'Accra', 'country_code' => 'GH'],
                ],
            ], 200),
        ]);
    }
}
