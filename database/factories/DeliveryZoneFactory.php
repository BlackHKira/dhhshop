<?php

namespace Database\Factories;

use App\Models\DeliveryZone;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DeliveryZone>
 */
class DeliveryZoneFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'name' => $this->faker->randomElement(['Nội thành', 'Ngoại thành', 'Vùng lân cận']),
            'city' => 'Hà Nội',
            'district' => $this->faker->randomElement(['Cầu Giấy', 'Hoàn Kiếm', 'Ba Đình', 'Đống Đa']),
            'delivery_fee' => $this->faker->randomElement([20000, 25000, 30000]),
            'is_active' => true,
        ];
    }
}
