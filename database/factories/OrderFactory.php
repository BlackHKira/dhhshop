<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $subtotal = $this->faker->numberBetween(200000, 20000000);
        $deliveryFee = 25000;

        return [
            'store_id' => Store::factory(),
            'user_id' => User::factory(),
            'code' => 'DH-'.$this->faker->unique()->numerify('#########'),
            'status' => 'pending',
            'payment_method' => 'cod',
            'payment_status' => 'unpaid',
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,
            'total' => $subtotal + $deliveryFee,
            'receiver_name' => fake()->name(),
            'phone' => $this->faker->numerify('09########'),
            'address_line' => $this->faker->streetAddress(),
            'district' => 'Cầu Giấy',
            'city' => 'Hà Nội',
            'note' => null,
            'idempotency_key' => null,
        ];
    }

    public function bankTransfer(): static
    {
        return $this->state(fn () => ['payment_method' => 'bank_transfer']);
    }

    public function paid(): static
    {
        return $this->state(fn () => ['payment_status' => 'paid']);
    }

    public function confirmed(): static
    {
        return $this->state(fn () => ['status' => 'confirmed']);
    }

    public function canceled(): static
    {
        return $this->state(fn () => [
            'status' => 'canceled',
            'cancel_reason' => 'Khách hủy',
        ]);
    }
}
