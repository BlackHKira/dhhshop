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
// ── Phase 2 seed: roles + store + settings + zones + catalog + inventory + demo users ──
const ROLES = [
    { slug: 'system_admin', name: 'System Admin', scope: 'system', description: 'Quản trị toàn hệ thống' },
    { slug: 'customer', name: 'Customer', scope: 'system', description: 'Khách hàng' },
    { slug: 'seller', name: 'Seller', scope: 'store', description: 'Nhân viên bán hàng / cửa hàng' },
    { slug: 'shipper', name: 'Shipper', scope: 'store', description: 'Giao hàng' },
    { slug: 'viewer', name: 'Viewer', scope: 'store', description: 'Chỉ xem' },
];
const DEMO_USERS = [
    { email: 'admin@demo.com', password: 'admin123', name: 'Admin', claim: 'system_admin' },
    { email: 'seller@demo.com', password: 'seller123', name: 'Seller', claim: 'seller' },
    { email: 'shipper@demo.com', password: 'shipper123', name: 'Shipper', claim: 'shipper' },
    { email: 'viewer@demo.com', password: 'viewer123', name: 'Viewer', claim: 'viewer' },
    { email: 'customer@demo.com', password: 'customer123', name: 'Customer', claim: 'customer' },
];
const STORE = { id: 'main', name: 'Cửa hàng Điện tử DH', slug: 'hddshop' };
const SETTINGS = {
    opening_hours: { mon_fri: '08:00-20:00', sat_sun: '09:00-18:00' },
    delivery_fee_flat: 25000,
    bank_bin: '970422',
    bank_account_no: '0123456789',
    bank_account_name: 'HOANG DUY HUY',
};
const ZONES = [
    { id: 'ha_noi_dong_da', name: 'Nội thành Hà Nội', city: 'Hà Nội', district: 'Đống Đa', delivery_fee: 15000, is_active: true },
    { id: 'ha_noi_toan', name: 'Hà Nội toàn TP', city: 'Hà Nội', district: '', delivery_fee: 30000, is_active: true },
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
    const isAdminCaller = !!request.auth && request.auth.token && request.auth.token.system_admin === true;
    if (!isEmulator && !isAdminCaller) {
        throw new https_1.HttpsError('permission-denied', 'Chỉ System Admin được seed dữ liệu demo.');
    }
    const storeRef = db.collection('stores').doc(STORE.id);
    const storeSnap = await storeRef.get();
    const storeExists = storeSnap.exists;
    await db.runTransaction(async (tx) => {
        for (const role of ROLES) {
            tx.set(db.collection('roles').doc(role.slug), role);
        }
        // Store + catalog chỉ ghi khi chưa tồn tại → seed lần 2 không ghi đè
        // sản phẩm/giá sau khi đã chỉnh sửa thật.
        if (storeExists)
            return;
        tx.set(storeRef, {
            name: STORE.name,
            slug: STORE.slug,
            is_active: true,
            created_at: now(),
        });
        for (const [key, value] of Object.entries(SETTINGS)) {
            tx.set(storeRef.collection('settings').doc(key), { value });
        }
        for (const z of ZONES) {
            tx.set(storeRef.collection('delivery_zones').doc(z.id), {
                name: z.name, city: z.city, district: z.district,
                delivery_fee: z.delivery_fee, is_active: z.is_active,
            });
        }
        for (const role of ROLES) {
            tx.set(db.collection('roles').doc(role.slug), role);
        }
        for (const c of CATEGORIES) {
            tx.set(db.collection('categories').doc(c.slug), {
                store_id: STORE.id, name: c.name, sort_order: 0, is_active: true,
            });
        }
        for (const p of PRODUCTS) {
            const ref = db.collection('products').doc(p.slug);
            tx.set(ref, {
                store_id: STORE.id,
                category_id: p.category,
                sku: p.sku,
                name: p.name,
                description: p.name,
                price: p.price,
                image_data: '',
                is_available: true,
                embedding: [],
                sort_order: 0,
                is_deleted: false,
                created_at: now(),
                updated_at: now(),
            });
            for (const [k, v] of Object.entries(p.specs)) {
                tx.set(ref.collection('specs').doc(k), { value: v });
            }
            tx.set(db.collection('inventory').doc(`${STORE.id}_${p.slug}`), {
                store_id: STORE.id,
                product_id: p.slug,
                stock_on_hand: p.stock,
                stock_reserved: 0,
                stock_available: p.stock,
                updated_at: now(),
            });
        }
    });
    for (const u of DEMO_USERS) {
        try {
            const record = await auth.createUser({
                email: u.email,
                password: u.password,
                displayName: u.name,
            });
            await auth.setCustomUserClaims(record.uid, { [u.claim]: true });
            await db.collection('users').doc(record.uid).set({
                email: u.email,
                name: u.name,
                phone: '',
                is_active: true,
                created_at: now(),
            });
            const isStoreRole = u.claim === 'seller' || u.claim === 'shipper' || u.claim === 'viewer';
            if (isStoreRole) {
                await db.collection('users').doc(record.uid).collection('roles').doc(u.claim).set({
                    assigned_by: 'seed',
                    assigned_at: now(),
                });
            }
        }
        catch {
            // email/UID đã tồn tại (seed lần 2) → bỏ qua
        }
    }
    return { ok: true, store: STORE.id, products: PRODUCTS.length, users: DEMO_USERS.length };
});
//# sourceMappingURL=index.js.map