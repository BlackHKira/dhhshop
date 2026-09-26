<?php

namespace Database\Factories;

use App\Models\Delivery;
use App\Models\Order;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Delivery>
 */
class DeliveryFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory(),
            'store_id' => Store::factory(),
            'shipper_id' => User::factory(),
            'status' => 'shipping',
            'assigned_by' => User::factory(),
            'assigned_at' => now(),
            'cod_collected_amount' => 0,
            'note' => null,
        ];
    }

    public function delivering(): static
    {
        return $this->state(fn () => ['status' => 'delivering', 'picked_up_at' => now()]);
    }

    public function delivered(): static
    {
        return $this->state(fn () => ['status' => 'delivered', 'delivered_at' => now()]);
    }
}
