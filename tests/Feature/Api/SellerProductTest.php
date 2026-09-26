<?php

namespace Tests\Feature\Api;

use App\Models\Category;
use App\Models\Inventory;
use App\Models\Product;
use App\Models\Role;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SellerProductTest extends TestCase
{
    use RefreshDatabase;

    private ?Store $store = null;

    private function store(): Store
    {
        return $this->store ??= Store::factory()->create(['slug' => 'seller-store-'.uniqid(), 'is_active' => true]);
    }

    private function seller(): User
    {
        $user = User::factory()->create();
        $user->roles()->attach(Role::factory()->seller()->create());

        return $user;
    }

    private function customer(): User
    {
        return User::factory()->create();
    }

    private function itemPayload(array $overrides = []): array
    {
        $category = Category::factory()->create(['store_id' => $this->store()->id, 'name' => 'Điện thoại']);

        return array_merge([
            'category_id' => $category->id,
            'sku' => 'SKU-'.uniqid(),
            'name' => 'Sản phẩm mới',
            'description' => '<script>alert(1)</script> Mô tả sản phẩm',
            'price' => 1500000,
            'stock' => 10,
            'is_available' => true,
            'specs' => [
                ['key' => 'ram', 'value' => '8GB'],
                ['key' => 'rom', 'value' => '256GB'],
            ],
        ], $overrides);
    }

    private function seededProduct(): Product
    {
        $store = $this->store();
        $product = Product::factory()->create(['store_id' => $store->id, 'name' => 'SP hiện có', 'price' => 1000000]);
        Inventory::factory()->create(['store_id' => $store->id, 'product_id' => $product->id, 'stock_on_hand' => 5]);

        return $product;
    }

    public function test_customer_cannot_list_products(): void
    {
        Sanctum::actingAs($this->customer(), ['buy']);

        $this->getJson('/api/seller/products')->assertStatus(403);
    }

    public function test_seller_lists_own_products(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);
        $this->store();
        $product = $this->seededProduct();

        $this->getJson('/api/seller/products')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $product->id)
            ->assertJsonPath('data.0.stock_available', 5);
    }

    public function test_customer_cannot_create_product(): void
    {
        Sanctum::actingAs($this->customer(), ['buy', 'chat']);

        $this->postJson('/api/seller/products', $this->itemPayload())->assertStatus(403);
    }

    public function test_unauth_cannot_create_product(): void
    {
        $this->postJson('/api/seller/products', $this->itemPayload())->assertStatus(401);
    }

    public function test_seller_can_create_product_with_inventory_and_specs(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);
        $store = $this->store();

        $this->postJson('/api/seller/products', $this->itemPayload())
            ->assertStatus(201)
            ->assertJsonPath('data.name', 'Sản phẩm mới')
            ->assertJsonPath('data.price', 1500000)
            ->assertJsonPath('data.specs.ram', '8GB')
            ->assertJsonPath('data.stock_available', 10);

        $this->assertDatabaseHas('products', ['store_id' => $store->id, 'name' => 'Sản phẩm mới']);
        $this->assertDatabaseHas('inventory', ['store_id' => $store->id, 'stock_on_hand' => 10]);
        $this->assertDatabaseHas('stock_movements', ['type' => 'purchase', 'quantity' => 10]);
    }

    public function test_seller_can_create_product_without_category_and_description(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);
        $payload = $this->itemPayload();
        unset($payload['category_id'], $payload['description']);

        $this->postJson('/api/seller/products', $payload)
            ->assertStatus(201)
            ->assertJsonPath('data.category_id', null)
            ->assertJsonPath('data.description', '');
    }

    public function test_product_description_is_sanitized(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);

        $this->postJson('/api/seller/products', $this->itemPayload())
            ->assertStatus(201)
            ->assertJsonPath('data.description', 'Mô tả sản phẩm');
    }

    public function test_seller_can_update_product(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);
        $product = $this->seededProduct();

        $this->putJson("/api/seller/products/{$product->id}", $this->itemPayload(['name' => 'Đã đổi tên']))
            ->assertOk()
            ->assertJsonPath('data.name', 'Đã đổi tên');

        $this->assertDatabaseHas('products', ['id' => $product->id, 'name' => 'Đã đổi tên']);
    }

    public function test_seller_cannot_edit_another_stores_product(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);
        $this->store();
        $otherStore = Store::factory()->create(['slug' => 'other-store-'.uniqid()]);
        $foreignProduct = Product::factory()->create(['store_id' => $otherStore->id, 'name' => 'Của cửa hàng khác']);
        Inventory::factory()->create(['store_id' => $otherStore->id, 'product_id' => $foreignProduct->id]);

        $this->putJson("/api/seller/products/{$foreignProduct->id}", $this->itemPayload())
            ->assertStatus(403);
    }

    public function test_seller_can_soft_delete_product(): void
    {
        Sanctum::actingAs($this->seller(), ['manage-catalog']);
        $product = $this->seededProduct();

        $this->deleteJson("/api/seller/products/{$product->id}")->assertOk();
        $this->assertSoftDeleted('products', ['id' => $product->id]);
    }
}
