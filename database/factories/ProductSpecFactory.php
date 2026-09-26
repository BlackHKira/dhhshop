<?php

namespace Database\Factories;

use App\Models\Product;
use App\Models\ProductSpec;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProductSpec>
 */
class ProductSpecFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'product_id' => Product::factory(),
            'spec_key' => $this->faker->randomElement(['ram', 'rom', 'screen', 'battery', 'cpu']),
            'spec_value' => $this->faker->word(),
        ];
    }
}
