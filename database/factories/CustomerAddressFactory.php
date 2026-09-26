<?php

namespace Database\Factories;

use App\Models\CustomerAddress;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<CustomerAddress>
 */
class CustomerAddressFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'label' => 'Nhà',
            'receiver_name' => fake()->name(),
            'phone' => $this->faker->numerify('09########'),
            'address_line' => $this->faker->streetAddress(),
            'district' => $this->faker->randomElement(['Cầu Giấy', 'Hoàn Kiếm', 'Ba Đình', 'Đống Đa', 'Hai Bà Trưng']),
            'city' => 'Hà Nội',
            'is_default' => false,
        ];
    }

    public function default(): static
    {
        return $this->state(fn () => ['is_default' => true]);
    }
}
