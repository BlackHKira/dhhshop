<?php

namespace Tests\Feature\Api;

use App\Models\Category;
use App\Models\Inventory;
use App\Models\Product;
use App\Models\Store;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CatalogTest extends TestCase
{
    use RefreshDatabase;

    private ?Store $store = null;

    private function store(): Store
    {
        return $this->store ??= Store::factory()->create(['slug' => 'test-store-'.uniqid()]);
    }

    private function product(array $overrides = []): Product
    {
        $store = $this->store();
        $category = Category::factory()->create(['store_id' => $store->id, 'name' => 'Điện thoại']);
        $product = Product::factory()->create(array_merge([
            'store_id' => $store->id,
            'category_id' => $category->id,
            'name' => 'iPhone 15 Pro',
            'price' => 27990000,
        ], $overrides));
        Inventory::factory()->create(['store_id' => $store->id, 'product_id' => $product->id, 'stock_on_hand' => 25]);

        return $product;
    }

    public function test_public_index_lists_available_products_with_stock(): void
    {
        $this->product();

        $this->getJson('/api/catalog')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'iPhone 15 Pro')
            ->assertJsonPath('data.0.stock_available', 25)
            ->assertJsonPath('data.0.category.name', 'Điện thoại');
    }

    public function test_public_index_excludes_unavailable_and_deleted_products(): void
    {
        $this->product(['name' => 'Available']);
        $this->product(['name' => 'Hidden', 'is_available' => false]);
        $this->product(['name' => 'Trashed'])->delete();

        $this->getJson('/api/catalog')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Available');
    }

    public function test_public_index_search_by_name(): void
    {
        $this->product(['name' => 'iPhone 15 Pro']);
        $this->product(['name' => 'MacBook Air M3']);
        $category2 = Category::factory()->create(['store_id' => $this->store()->id, 'name' => 'Máy tính']);
        Inventory::factory()->create(['store_id' => $this->store()->id, 'product_id' => Product::factory()->create([
            'store_id' => $this->store()->id,
            'category_id' => $category2->id,
            'name' => 'MacBook Air M3 13 inch',
            'price' => 27990000,
        ])->id]);

        $this->getJson('/api/catalog?search=iphone')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'iPhone 15 Pro');
    }

    public function test_public_index_sorts_by_price_asc(): void
    {
        $this->product(['name' => 'Cheap', 'price' => 100000]);
        $this->product(['name' => 'Expensive', 'price' => 9000000]);

        $this->getJson('/api/catalog?sort=price_asc')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Cheap')
            ->assertJsonPath('data.1.name', 'Expensive');
    }

    public function test_public_show_returns_specs(): void
    {
        $this->product()->specs()->createMany([
            ['spec_key' => 'ram', 'spec_value' => '8GB'],
            ['spec_key' => 'rom', 'spec_value' => '256GB'],
        ]);

        $product = Product::with(['category', 'inventory', 'specs'])->first();

        $this->getJson("/api/catalog/{$product->id}")
            ->assertOk()
            ->assertJsonPath('data.specs.ram', '8GB')
            ->assertJsonPath('data.specs.rom', '256GB')
            ->assertJsonPath('data.stock_available', 25);
    }

    public function test_public_categories_lists_active_store_categories(): void
    {
        Category::factory()->count(2)->create(['store_id' => $this->store()->id]);
        $inactiveStore = Store::factory()->create(['slug' => 'inactive-store-'.uniqid(), 'is_active' => false]);
        Category::factory()->create(['store_id' => $inactiveStore->id]);

        $this->getJson('/api/categories')
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_public_show_404_for_unknown_product(): void
    {
        $this->getJson('/api/catalog/999999')->assertStatus(404);
    }
}
