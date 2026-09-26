<?php

namespace Database\Factories;

use App\Models\Role;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Role>
 */
class RoleFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'slug' => $this->faker->unique()->word(),
            'name' => $this->faker->words(2, true),
            'scope' => 'system',
            'description' => null,
        ];
    }

    public function customer(): static
    {
        return $this->state(fn () => ['slug' => 'customer', 'name' => 'Khách hàng']);
    }

    public function seller(): static
    {
        return $this->state(fn () => ['slug' => 'seller', 'name' => 'Người bán', 'scope' => 'store']);
    }

    public function shipper(): static
    {
        return $this->state(fn () => ['slug' => 'shipper', 'name' => 'Người giao hàng', 'scope' => 'store']);
    }

    public function systemAdmin(): static
    {
        return $this->state(fn () => ['slug' => 'system_admin', 'name' => 'Quản trị hệ thống']);
    }

    public function viewer(): static
    {
        return $this->state(fn () => ['slug' => 'viewer', 'name' => 'Người xem', 'scope' => 'store']);
    }
}
