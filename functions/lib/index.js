"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.seedDemoData = exports.ping = void 0;
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
const auth = (0, auth_1.getAuth)();
const now = () => firestore_1.FieldValue.serverTimestamp();
/* ══════════════════════════════════════════════════════════════
   Seed cho FIRESTORE EMULATOR (dev/test) — không deploy production.
   Gói Spark không có Cloud Functions ở production; chạy thật bằng
   scripts/seed_production.mjs (Admin SDK local) hoặc script client.

   Mô hình dữ liệu — đồ án chỉ có MỘT cửa hàng:
     - KHÔNG có collection `roles`; vai trò là `users/{uid}.role`.
     - KHÔNG có collection `stores`; cấu hình ở `settings/store`.
     - KHÔNG dùng custom claims; Rules đọc thẳng doc user.
     - Không doc nào mang `store_id`; `inventory` docID = productId.
     - Xoá mềm dùng `deleted_at` (null = còn bán).
   ══════════════════════════════════════════════════════════════ */
const DEMO_USERS = [
    { email: 'admin@demo.com', password: 'admin123', name: 'Admin', role: 'admin' },
    { email: 'seller@demo.com', password: 'seller123', name: 'Seller', role: 'seller' },
    { email: 'customer@demo.com', password: 'customer123', name: 'Khách hàng', role: 'customer' },
];
/** docID cố định của cấu hình cửa hàng. */
const STORE_DOC_ID = 'store';
const STORE = {
    name: 'Cửa hàng Điện tử DH',
    phone: '0918433866',
    address: 'Số 1, Đống Đa, Hà Nội',
};
/* `bank_*` là dữ liệu CÔNG KHAI để client dựng payload VietQR — không phải secret. */
const SETTINGS = {
    opening_hours: { mon_fri: '08:00-20:00', sat_sun: '09:00-18:00' },
    delivery_fee_flat: 25000,
    bank_bin: '970422',
    bank_account_no: '0123456789',
    bank_account_name: 'ĐẶNG HUY HOÀNG',
};
const ZONES = [
    { id: 'ha_noi_dong_da', name: 'Nội thành Hà Nội', city: 'Hà Nội', district: 'Đống Đa', delivery_fee: 15000, is_active: true },
    { id: 'ha_noi_toan', name: 'Hà Nội toàn TP', city: 'Hà Nội', district: 'Toàn TP', delivery_fee: 30000, is_active: true },
];
const CATEGORIES = [
    { slug: 'dien-thoai', name: 'Điện thoại' },
    { slug: 'laptop', name: 'Laptop' },
    { slug: 'phu-kien', name: 'Phụ kiện' },
];
const PRODUCTS = [
    { slug: 'iphone-15-pro-max', category: 'dien-thoai', sku: 'IP15PM-512', name: 'iPhone 15 Pro Max 512GB', price: 34990000, stock: 15, specs: { ram: '8GB', rom: '512GB', screen: '6.7-inch OLED', battery: '4441 mAh', os: 'iOS 17' } },
    { slug: 'galaxy-s24-ultra', category: 'dien-thoai', sku: 'S24U-512', name: 'Samsung Galaxy S24 Ultra 512GB', price: 31990000, stock: 20, specs: { ram: '12GB', rom: '512GB', screen: '6.8-inch AMOLED', battery: '5000 mAh', os: 'Android 14' } },
    { slug: 'macbook-air-m2', category: 'laptop', sku: 'MBA-M2-256', name: 'MacBook Air 13-inch M2 256GB', price: 29990000, stock: 10, specs: { cpu: 'Apple M2', ram: '8GB', rom: '256GB SSD', screen: '13.6-inch Liquid Retina' } },
    { slug: 'dell-xps-13', category: 'laptop', sku: 'XPS13-9340', name: 'Dell XPS 13 9340 (Core Ultra 5)', price: 38990000, stock: 8, specs: { cpu: 'Core Ultra 5 125U', ram: '16GB', rom: '512GB SSD', screen: '13.4-inch FHD+' } },
    { slug: 'airpods-pro-2', category: 'phu-kien', sku: 'AP2-USB-C', name: 'Apple AirPods Pro 2 (USB-C)', price: 6490000, stock: 30, specs: { driver: '2 cụm driver', bt: 'Bluetooth 5.3', anc: 'Có' } },
    { slug: 'sac-gan-65w', category: 'phu-kien', sku: 'CHG65-PD', name: 'Sạc nhanh GaN 65W PD 2 cổng', price: 990000, stock: 50, specs: { power: '65W', ports: 'USB-C + USB-A', pd: 'Có' } },
    { slug: 'pin-du-phong-10000', category: 'phu-kien', sku: 'PB10K-22', name: 'Sạc dự phòng 10000mAh 22.5W', price: 590000, stock: 40, specs: { capacity: '10000mAh', power: '22.5W', ports: '2 USB-A + 1 USB-C' } },
    { slug: 'ban-phim-co-a87', category: 'phu-kien', sku: 'KB-A87', name: 'Bàn phím cơ A87 (switch Red)', price: 1290000, stock: 25, specs: { layout: 'TKL 87', switch: 'Red linear', led: 'RGB' } },
];
exports.ping = (0, https_1.onRequest)((_req, res) => {
    res.json({ ok: true, service: 'hddshop-functions', time: new Date().toISOString() });
});
exports.seedDemoData = (0, https_1.onCall)(async (request) => {
    const isEmulator = !!process.env.FUNCTIONS_EMULATOR;
    if (!isEmulator) {
        throw new https_1.HttpsError('failed-precondition', 'Chỉ chạy được trên Emulator. Production dùng scripts/seed_production.mjs.');
    }
    const storeRef = db.collection('settings').doc(STORE_DOC_ID);
    const storeSnap = await storeRef.get();
    const storeExists = storeSnap.exists;
    // Cấu hình + catalog chỉ ghi khi chưa tồn tại → seed lần 2 không đè
    // sản phẩm/giá sau khi đã chỉnh sửa thật.
    if (!storeExists) {
        await db.runTransaction(async (tx) => {
            tx.set(storeRef, {
                name: STORE.name,
                phone: STORE.phone,
                address: STORE.address,
                ...SETTINGS,
                updated_at: now(),
            });
            for (const z of ZONES) {
                tx.set(db.collection('delivery_zones').doc(z.id), {
                    name: z.name,
                    city: z.city,
                    district: z.district,
                    delivery_fee: z.delivery_fee,
                    is_active: z.is_active,
                    deleted_at: null,
                });
            }
            for (const c of CATEGORIES) {
                tx.set(db.collection('categories').doc(c.slug), {
                    name: c.name,
                    sort_order: 0,
                    is_active: true,
                    deleted_at: null,
                });
            }
            for (const p of PRODUCTS) {
                const ref = db.collection('products').doc(p.slug);
                tx.set(ref, {
                    category_id: p.category,
                    sku: p.sku,
                    name: p.name,
                    description: p.name,
                    price: p.price,
                    image_data: '',
                    is_available: true,
                    embedding: [],
                    sort_order: 0,
                    deleted_at: null,
                    created_at: now(),
                    updated_at: now(),
                });
                for (const [k, v] of Object.entries(p.specs)) {
                    tx.set(ref.collection('specs').doc(k), { value: v });
                }
                // docID = productId (không còn tiền tố storeId)
                tx.set(db.collection('inventory').doc(p.slug), {
                    product_id: p.slug,
                    stock_on_hand: p.stock,
                    stock_reserved: 0,
                    stock_available: p.stock,
                    updated_at: now(),
                });
                // Nhật ký biến động tồn — admin đối chiếu tồn dựa vào đây.
                if (p.stock > 0) {
                    tx.set(db.collection('stock_movements').doc(), {
                        product_id: p.slug,
                        type: 'purchase',
                        quantity: p.stock,
                        reference_id: null,
                        reason: 'Nhập kho ban đầu (seed)',
                        actor_id: 'seed',
                        created_at: now(),
                    });
                }
            }
        });
    }
    for (const u of DEMO_USERS) {
        try {
            const record = await auth.createUser({
                email: u.email,
                password: u.password,
                displayName: u.name,
            });
            await db.collection('users').doc(record.uid).set({
                email: u.email,
                display_name: u.name,
                phone: '',
                role: u.role,
                is_active: true,
                created_at: now(),
                deleted_at: null,
            });
        }
        catch {
            // email/UID đã tồn tại (seed lần 2) → bỏ qua
        }
    }
    return {
        ok: true,
        store: STORE_DOC_ID,
        products: PRODUCTS.length,
        users: DEMO_USERS.length,
    };
});
//# sourceMappingURL=index.js.map