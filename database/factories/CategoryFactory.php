<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Category>
 */
class CategoryFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'store_id' => Store::factory(),
            'name' => $this->faker->unique()->randomElement(['Điện thoại', 'Laptop', 'Tai nghe', 'Phụ kiện', 'Đồng hồ thông minh', 'Loa đầu', 'Màn hình']),
            'sort_order' => 0,
            'is_active' => true,
        ];
    }
}
