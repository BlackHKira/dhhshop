<?php

namespace Database\Factories;

use App\Models\Store;
use App\Models\StoreSetting;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<StoreSetting>
 */
class StoreSettingFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'key' => $this->faker->unique()->word(),
            'value' => ['value' => $this->faker->word()],
        ];
    }

    public function bankInfo(): static
    {
        return $this->state(fn () => [
            'key' => 'bank_info',
            'value' => [
                'bank_bin' => '970415',
                'bank_account_no' => '190912345678',
                'bank_account_name' => 'CỬA HÀNG ĐIỆN TỬ',
            ],
        ]);
    }

    public function openingHours(): static
    {
        return $this->state(fn () => [
            'key' => 'opening_hours',
            'value' => ['open' => '08:00', 'close' => '21:00', 'display' => 'T2–CN 08:00–21:00'],
        ]);
    }

    public function flatDeliveryFee(): static
    {
        return $this->state(fn () => [
            'key' => 'delivery_fee_flat',
            'value' => ['amount' => 25000],
        ]);
    }
}
