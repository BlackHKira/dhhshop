<?php

namespace Database\Factories;

use App\Models\Inventory;
use App\Models\Product;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Inventory>
 */
class InventoryFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'product_id' => Product::factory(),
            'stock_on_hand' => $this->faker->numberBetween(0, 500),
            'stock_reserved' => 0,
        ];
    }

    public function outOfStock(): static
    {
        return $this->state(fn () => ['stock_on_hand' => 0]);
    }
}
