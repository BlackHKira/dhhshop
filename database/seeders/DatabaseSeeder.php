<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\DeliveryZone;
use App\Models\Inventory;
use App\Models\Product;
use App\Models\Role;
use App\Models\StockMovement;
use App\Models\Store;
use App\Models\User;
use App\Models\UserRole;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::create([
            'name' => 'Quản trị hệ thống',
            'email' => 'admin@demo.vn',
            'password' => 'password',
            'phone' => '0912345678',
            'is_active' => true,
        ]);

        $sellerUser = User::create([
            'name' => 'Chủ cửa hàng',
            'email' => 'seller@demo.vn',
            'password' => 'password',
            'phone' => '0912345679',
            'is_active' => true,
        ]);

        $shipperUser = User::create([
            'name' => 'Nhân viên giao hàng',
            'email' => 'shipper@demo.vn',
            'password' => 'password',
            'phone' => '0912345680',
            'is_active' => true,
        ]);

        $customerUser = User::create([
            'name' => 'Khách hàng Demo',
            'email' => 'customer@demo.vn',
            'password' => 'password',
            'phone' => '0912345681',
            'is_active' => true,
        ]);

        $viewerUser = User::create([
            'name' => 'Người xem',
            'email' => 'viewer@demo.vn',
            'password' => 'password',
            'is_active' => true,
        ]);

        $roles = [
            'system_admin' => ['name' => 'Quản trị hệ thống', 'scope' => 'system'],
            'customer' => ['name' => 'Khách hàng', 'scope' => 'system'],
            'seller' => ['name' => 'Người bán', 'scope' => 'store'],
            'shipper' => ['name' => 'Người giao hàng', 'scope' => 'store'],
            'viewer' => ['name' => 'Người xem', 'scope' => 'store'],
        ];

        $roleIds = [];
        foreach ($roles as $slug => $def) {
            $role = Role::query()->firstOrCreate(['slug' => $slug], $def);
            $roleIds[$slug] = $role->id;
        }

        $assignments = [
            'system_admin' => $admin->id,
            'seller' => $sellerUser->id,
            'shipper' => $shipperUser->id,
            'customer' => $customerUser->id,
            'viewer' => $viewerUser->id,
        ];

        foreach ($assignments as $slug => $userId) {
            UserRole::query()->firstOrCreate([
                'user_id' => $userId,
                'role_id' => $roleIds[$slug],
                'assigned_by' => $admin->id,
            ]);
        }

        $store = Store::query()->firstOrCreate(
            ['slug' => 'dien-tu-demo'],
            [
                'name' => 'Cửa hàng Điện tử Demo',
                'description' => 'Cửa hàng bán đồ điện tử mẫu cho đồ án (điện thoại, laptop, phụ kiện).',
                'address' => 'Số 1, Vĩnh Tuy, Hai Bà Trưng, Hà Nội',
                'phone' => '024 1234 5678',
                'is_active' => true,
                'created_by' => $sellerUser->id,
            ]
        );

        $store->settings()->delete();
        $store->settings()->createMany([
            [
                'key' => 'bank_info',
                'value' => [
                    'bank_bin' => '970415',
                    'bank_account_no' => '190912345678',
                    'bank_account_name' => 'CUA HANG DIEN TU DEMO',
                ],
            ],
            [
                'key' => 'opening_hours',
                'value' => ['open' => '08:00', 'close' => '21:00', 'display' => 'T2–CN 08:00–21:00'],
            ],
            [
                'key' => 'delivery_fee_flat',
                'value' => ['amount' => 25000],
            ],
        ]);

        $store->deliveryZones()->delete();
        $zones = [
            ['name' => 'Nội thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Cầu Giấy', 'delivery_fee' => 15000],
            ['name' => 'Nội thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Hoàn Kiếm', 'delivery_fee' => 15000],
            ['name' => 'Nội thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Ba Đình', 'delivery_fee' => 15000],
            ['name' => 'Nội thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Đống Đa', 'delivery_fee' => 15000],
            ['name' => 'Nội thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Hai Bà Trưng', 'delivery_fee' => 15000],
            ['name' => 'Ngoại thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Long Biên', 'delivery_fee' => 20000],
            ['name' => 'Ngoại thành Hà Nội', 'city' => 'Hà Nội', 'district' => 'Gia Lâm', 'delivery_fee' => 25000],
            ['name' => 'Hà Nội (cả thành phố)', 'city' => 'Hà Nội', 'district' => null, 'delivery_fee' => 30000],
            ['name' => 'TP. Hồ Chí Minh', 'city' => 'TP. Hồ Chí Minh', 'district' => null, 'delivery_fee' => 35000],
        ];
        foreach ($zones as $zone) {
            DeliveryZone::query()->create(array_merge($zone, ['is_active' => true, 'store_id' => $store->id]));
        }

        $categories = ['Điện thoại', 'Laptop', 'Tai nghe', 'Phụ kiện', 'Đồng hồ thông minh', 'Loa và âm thanh', 'Màn hình'];
        $categoryIds = [];
        foreach ($categories as $i => $name) {
            $category = Category::query()->create([
                'store_id' => $store->id,
                'name' => $name,
                'sort_order' => $i,
                'is_active' => true,
            ]);
            $categoryIds[$name] = $category->id;
        }

        $catalog = [
            ['Điện thoại', 'iPhone 15 Pro Max 256GB', 27990000, '6.7 inch', '128GB'],
            ['Điện thoại', 'Samsung Galaxy S24 Ultra', 28990000, '6.8 inch'],
            ['Điện thoại', 'Xiaomi 14', 15990000, '6.36 inch'],
            ['Điện thoại', 'OPPO Reno11 5G', 8490000, '6.7 inch', '256GB'],
            ['Điện thoại', 'realme GT6 5G', 11990000, '6.78 inch'],
            ['Laptop', 'MacBook Air M3 13"', 27990000, '13.6 inch', '256GB'],
            ['Laptop', 'MacBook Pro M3 Pro 14"', 42990000, '14.2 inch'],
            ['Laptop', 'Dell XPS 13 9380', 31990000, '13.4 inch'],
            ['Laptop', 'HP Envy x360', 21990000, '15.6 inch'],
            ['Laptop', 'Lenovo Legion 5', 25990000, '15.6 inch'],
            ['Tai nghe', 'AirPods Pro 2', 6490000, 'ANC'],
            ['Tai nghe', 'Sony WH-1000XM5', 8990000, 'Over-ear'],
            ['Tai nghe', 'Samsung Buds 2 Pro', 3990000, 'In-ear'],
            ['Phụ kiện', 'Anker GaN 65W sạc nhanh', 899000, '65W'],
            ['Phụ kiện', 'Cáp USB-C Anker 1m', 199000, 'USB-C'],
            ['Đồng hồ thông minh', 'Apple Watch Series 9', 10590000, '41mm'],
            ['Đồng hồ thông minh', 'Samsung Galaxy Watch6', 6490000, '40mm'],
            ['Loa và âm thanh', 'JBL Charge 5', 3290000, 'Bluetooth'],
            ['Loa và âm thanh', 'Marshall Acton III', 6490000, 'Nhà'],
            ['Màn hình', 'LG UltraFine 27UQ850', 14990000, '27 inch'],
        ];

        $store->products()->delete();
        Inventory::query()->where('store_id', $store->id)->delete();
        StockMovement::query()->where('store_id', $store->id)->delete();

        $seq = 0;
        foreach ($catalog as $i => [$categoryName, $name, $price, $specKey]) {
            $seq++;
            $extraSpec = $catalog[$i][4] ?? null;
            $categoryId = $categoryIds[$categoryName];
            $product = Product::query()->create([
                'store_id' => $store->id,
                'category_id' => $categoryId,
                'sku' => 'SKU-'.str_pad((string) $seq, 5, '0', STR_PAD_LEFT),
                'name' => $name,
                'description' => "Sản phẩm $name — hàng chính hãng, bảo hành 12 tháng, đổi trả trong 7 ngày.",
                'price' => $price,
                'image_url' => null,
                'is_available' => true,
                'sort_order' => $seq,
            ]);

            $product->specs()->create([
                'spec_key' => 'screen',
                'spec_value' => $specKey,
            ]);
            if ($extraSpec !== null) {
                $product->specs()->create([
                    'spec_key' => 'rom',
                    'spec_value' => $extraSpec,
                ]);
            }

            $stock = $product->inventory()->create([
                'store_id' => $store->id,
                'stock_on_hand' => rand(10, 200),
                'stock_reserved' => 0,
            ]);

            StockMovement::query()->create([
                'store_id' => $store->id,
                'product_id' => $product->id,
                'type' => 'purchase',
                'quantity' => $stock->stock_on_hand,
                'reason' => 'Nhập kho ban đầu (seed)',
                'actor_id' => $sellerUser->id,
                'created_at' => now(),
            ]);
        }
    }
}
