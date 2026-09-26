<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\Payment;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Payment>
 */
class PaymentFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'payable_type' => Order::class,
            'payable_id' => Order::factory(),
            'store_id' => Store::factory(),
            'method' => 'cod',
            'status' => 'pending',
            'amount' => $this->faker->numberBetween(200000, 20000000),
            'bank_txn_ref' => null,
            'items_snapshot' => null,
            'created_by' => User::factory(),
        ];
    }

    public function bankTransfer(): static
    {
        return $this->state(fn () => ['method' => 'bank_transfer']);
    }

    public function paid(): static
    {
        return $this->state(fn () => ['status' => 'paid', 'paid_at' => now()]);
    }

    public function refunded(): static
    {
        return $this->state(fn () => ['status' => 'refunded', 'refunded_at' => now()]);
    }
}
