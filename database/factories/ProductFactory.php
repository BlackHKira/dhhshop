<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Product;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'category_id' => Category::factory(),
            'sku' => 'SKU-'.$this->faker->unique()->numerify('#######'),
            'name' => $this->faker->words(3, true),
            'description' => $this->faker->paragraph(),
            'price' => $this->faker->randomFloat(0, 100000, 25000000),
            'image_url' => null,
            'is_available' => true,
            'sort_order' => 0,
        ];
    }

    public function unavailable(): static
    {
        return $this->state(fn () => ['is_available' => false]);
    }

    public function withSpecs(): static
    {
        return $this->afterCreating(function (Product $product) {
            $product->specs()->createMany([
                ['spec_key' => 'ram', 'spec_value' => '8GB'],
                ['spec_key' => 'rom', 'spec_value' => '256GB'],
                ['spec_key' => 'screen', 'spec_value' => '6.7 inch'],
            ]);
        });
    }
}
