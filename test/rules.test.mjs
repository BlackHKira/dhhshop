/* ============================================================
   KIỂM THỬ SECURITY RULES — DHHShop (18 entity / 3 vai trò)

   Chạy:  npm run test:rules:emulator
   Bắt buộc qua Emulator — Rules chỉ được thật sự kiểm trong môi trường
   Firestore, không kiểm được bằng cách đọc file .rules.

   LƯU Ý: Firestore Emulator (Java) không đọc được đường dẫn có dấu
   tiếng Việt. Nếu thư mục dự án nằm ở "đồ án", phải tạo junction
   đường dẫn ASCII trước (xem README hoặc chạy test/run-rules-test.ps1).

   Mỗi phép thử ghi rõ AI ĐƯỢC và AI KHÔNG ĐƯỢC — nếu Rules nới quá tay,
   test sẽ đỏ chứ không im lặng.
   ============================================================ */

import {
  initializeTestEnvironment, assertSucceeds, assertFails
} from '@firebase/rules-unit-testing';
import { serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RULES = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

const U = {
  khach: 'khach01',
  khach2: 'khach02',
  /* user thứ ba luôn giữ role customer — dùng để kiểm tra "khách này có đọc
     / ghi được vào dữ liệu của khách khác không". Tách riêng vì khach02 bị
     nâng lên seller trong testUsers, nên nếu dùng lại sẽ thành staff và
     các phép thử quyền sẽ cho kết quả sai. */
  khach3: 'khach03',
  seller: 'seller01',
  admin: 'admin01',
  hacker: 'hacker01',  // role không hợp lệ — phải bị chặn ở mọi nơi
  /* user RIÊNG cho phép thử enum role + khoá tài khoản. Tách riêng vì
     khach02 bị nâng lên seller, còn khach03 phải giữ role customer cho các
     phép thử quyền khác — dùng lại sẽ làm hỏng kết quả những phép thử đó. */
  khac4: 'khach04'
};

/* Rules đòi created_at / updated_at == request.time, nên phải dùng
   serverTimestamp() của SDK — đặt số tay sẽ luôn bị chặn. */
const NOW = () => serverTimestamp();

let testEnv;
const results = [];

/* tự bắt lỗi để biết chính xác phép thử nào hỏng, không dừng cả nhóm */
async function canDo(name, fn) {
  try { await assertSucceeds(fn()); results.push({ name, ok: true }); }
  catch (e) { results.push({ name, ok: false, detail: 'KHONG DUOC - ' + short(e) }); }
}
async function cantDo(name, fn) {
  try { await assertFails(fn()); results.push({ name, ok: true }); }
  catch (e) { results.push({ name, ok: false, detail: 'VAN CHO PHEP - ' + short(e) }); }
}
function short(e) {
  const m = (e && e.message) || String(e);
  return m.split('\n')[0].slice(0, 130);
}

const userDoc = (uid, role) => ({
  email: uid + '@demo.com', display_name: uid, phone: '0912345678',
  role, is_active: true, created_at: NOW(), deleted_at: null
});
const orderDoc = (uid, over = {}) => ({
  user_id: uid, code: 'DH2405', status: 'pending',
  payment_method: 'cod', payment_status: 'unpaid',
  subtotal: 1000000, delivery_fee: 15000, total: 1015000,
  receiver_name: 'Pham Minh Anh', phone: '0912345678',
  address_line: '83 Thai Ha', district: 'Dong Da', city: 'Ha Noi',
  note: '', created_at: NOW(), deleted_at: null, ...over
});

function asCtx(uid) { return testEnv.authenticatedContext(uid, { role: '' }).firestore(); }
const get = (db, ...p) => db.doc(p.join('/')).get();
const set = (db, ...p) => db.doc(p.slice(0, -1).join('/')).set(p[p.length - 1]);
const upd = (db, ...p) => db.doc(p.slice(0, -1).join('/')).update(p[p.length - 1]);
const del = (db, ...p) => db.doc(p.join('/')).delete();

/* ============================================================
   NHÓM A — users, phân quyền, cấu hình
   ============================================================ */
async function testUsers() {
  await canDo('users · khách đọc hồ sơ của chính mình',
    () => get(asCtx(U.khach), 'users', U.khach));
  await cantDo('users · khách KHÔNG đọc hồ sơ người khác',
    () => get(asCtx(U.khach), 'users', U.khach2));
  await canDo('users · seller đọc hồ sơ khách (cho tem giao hàng)',
    () => get(asCtx(U.seller), 'users', U.khach));
  await cantDo('users · khách văng KHÔNG đọc hồ sơ nào',
    () => get(testEnv.unauthenticatedContext().firestore(), 'users', U.khach));

  /* lỗ hổng nghiêm trọng nhất: tự nâng quyền */
  await cantDo('users · khách KHÔNG tự nâng lên admin',
    () => set(asCtx(U.khach), 'users', U.khach, userDoc(U.khach, 'admin')));
  await cantDo('users · khách KHÔNG đổi role sang seller',
    () => set(asCtx(U.khach), 'users', U.khach, userDoc(U.khach, 'seller')));
  await canDo('users · khách sửa tên / điện thoại của chính mình',
    () => upd(asCtx(U.khach), 'users', U.khach,
      { display_name: 'Pham Minh Anh Moi', phone: '0900000000' }));

  await canDo('users · admin nâng quyền cho người khác',
    () => set(asCtx(U.admin), 'users', U.khach2, userDoc(U.khach2, 'seller')));
  await cantDo('users · seller KHÔNG nâng quyền lên admin',
    () => set(asCtx(U.seller), 'users', U.khach2, userDoc(U.khach2, 'admin')));
  await cantDo('users · seller KHÔNG xoá tài khoản',
    () => del(asCtx(U.seller), 'users', U.khach2));

  /* --- enum vai trò: admin đổi được role, nhưng chỉ trong danh sách hợp lệ.
     Trước đây allow update chỉ có isAdmin() nên admin gõ role: 'hacker' là
     ghi được — tài khoản đó mất HẾT quyền (isCustomer/isAdmin/isStaff đều
     false) mà chính nó cũng không tự sửa lại được, vì nhánh tự sửa cũng cần
     isCustomer(). --- */
  await cantDo('users · admin KHÔNG đặt được role không hợp lệ',
    () => set(asCtx(U.admin), 'users', U.khac4, userDoc(U.khac4, 'hacker')));
  await canDo('users · admin nâng được lên admin',
    () => set(asCtx(U.admin), 'users', U.khac4, userDoc(U.khac4, 'admin')));
  await canDo('users · admin hạ được xuống customer',
    () => set(asCtx(U.admin), 'users', U.khac4, userDoc(U.khac4, 'customer')));

  /* --- is_active = false phải THẬT SỰ khoá được tài khoản.
     Trước đây không helper nào đọc is_active, nên đặt false vẫn giữ nguyên
     mọi quyền — thao tác khoá tài khoản khi có sự cố là thao tác vô nghĩa. --- */
  await canDo('users · admin khoá tài khoản được (is_active = false)',
    () => upd(asCtx(U.admin), 'users', U.khac4, { is_active: false }));

  await cantDo('khoá · KHÔNG tự sửa được hồ sơ của chính mình',
    () => upd(asCtx(U.khac4), 'users', U.khac4, { display_name: 'Ten Moi' }));
  await cantDo('khoá · KHÔNG thêm được địa chỉ',
    () => set(asCtx(U.khac4), 'users', U.khac4, 'addresses', 'a9', {
      label: 'Nha', receiver_name: 'PMH', phone: '0912345678',
      address_line: '83 Thai Ha', district: 'Dong Da', city: 'Ha Noi',
      is_default: true, created_at: NOW(), deleted_at: null }));
  await cantDo('khoá · KHÔNG đặt hàng được',
    () => set(asCtx(U.khac4), 'orders', 'LOCKED1', orderDoc(U.khac4)));
  await cantDo('khoá · KHÔNG đọc được hồ sơ người khác',
    () => get(asCtx(U.khac4), 'users', U.khach));
  await cantDo('khoá · KHÔNG xoá được dòng giỏ của chính mình',
    () => del(asCtx(U.khac4), 'users', U.khac4, 'carts', 'active', 'items', 'p1'));

  /* Cặp đối chứng: khoá KHÔNG có nghĩa mất sạch dữ liệu — vẫn đọc được hồ
     sơ của chính mình, để app hiện lý do tài khoản bị khoá. */
  await canDo('khoá · vẫn đọc được hồ sơ của chính mình',
    () => get(asCtx(U.khac4), 'users', U.khac4));

  await canDo('khoá · admin mở khoá lại được',
    () => upd(asCtx(U.admin), 'users', U.khac4, { is_active: true }));
  await canDo('mở khoá · tự sửa hồ sơ lại được',
    () => upd(asCtx(U.khac4), 'users', U.khac4, { display_name: 'Ten Moi' }));
}

async function testAddresses() {
  const addr = { label: 'Nha', receiver_name: 'PMH', phone: '0912345678',
    address_line: '83 Thai Ha', district: 'Dong Da', city: 'Ha Noi',
    is_default: true, created_at: NOW(), deleted_at: null };
  const P = ['users', U.khach, 'addresses', 'a1'];

  await canDo('addresses · khách thêm địa chỉ của chính mình',
    () => set(asCtx(U.khach), ...P, addr));
  await cantDo('addresses · khách KHÔNG thêm vào sổ của người khác',
    () => set(asCtx(U.khach3), 'users', U.khach, 'addresses', 'a2', addr));
  await cantDo('addresses · người có role không hợp lệ bị chặn',
    () => set(asCtx(U.hacker), 'users', U.hacker, 'addresses', 'a3', addr));
  await cantDo('addresses · khách KHÔNG xoá địa chỉ người khác',
    () => del(asCtx(U.khach3), ...P));
  await canDo('addresses · khách xoá địa chỉ của chính mình',
    () => del(asCtx(U.khach), ...P));
}

async function testSettingsAndZones() {
  const pub = testEnv.unauthenticatedContext().firestore();
  /* số tài khoản nhận tiền là public — khách cần đọc để dựng VietQR */
  await canDo('settings · đọc được khi chưa đăng nhập (khách cần số TK quét QR)',
    () => get(pub, 'settings', 'store'));
  await cantDo('settings · người văng KHÔNG sửa được',
    () => set(pub, 'settings', 'store', { name: 'Hack' }));
  await cantDo('settings · khách KHÔNG sửa được',
    () => set(asCtx(U.khach), 'settings', 'store', { name: 'Hack' }));
  await cantDo('settings · seller KHÔNG sửa được (chỉ admin)',
    () => set(asCtx(U.seller), 'settings', 'store', { name: 'Hack' }));
  await canDo('settings · admin sửa được',
    () => set(asCtx(U.admin), 'settings', 'store', { name: 'Cua hang' }));

  await canDo('delivery_zones · đọc công khai',
    () => get(pub, 'delivery_zones', 'ha_noi_dong_da'));
  await cantDo('delivery_zones · seller KHÔNG sửa được',
    () => set(asCtx(U.seller), 'delivery_zones', 'x', { fee: 0 }));
}

/* ============================================================
   NHÓM B — catalog
   ============================================================ */
async function testCatalog() {
  const pub = testEnv.unauthenticatedContext().firestore();
  const prod = { category_id: 'dien-thoai', sku: 'IP15P', name: 'iPhone 15 Pro Max',
    description: 'dien thoai', price: 27390000, image_data: 'data:image/jpeg;base64,AA',
    is_available: true, embedding: [], sort_order: 1,
    created_at: NOW(), updated_at: NOW(), deleted_at: null };

  await canDo('catalog · đọc sản phẩm khi chưa đăng nhập (storefront công khai)',
    () => get(pub, 'products', 'p1'));
  await canDo('catalog · seller thêm danh mục',
    () => set(asCtx(U.seller), 'categories', 'c1',
      { name: 'Dien thoai', sort_order: 1, is_active: true, created_at: NOW() }));
  await canDo('catalog · seller thêm sản phẩm',
    () => set(asCtx(U.seller), 'products', 'p1', prod));

  /* chặn lọt field tồn kho vào doc sản phẩm — lý do phải tách inventory */
  await cantDo('catalog · KHÔNG lọt được field tồn kho vào doc sản phẩm',
    () => set(asCtx(U.seller), 'products', 'p2', { ...prod, stock_on_hand: 999 }));
  await cantDo('catalog · giá âm bị chặn',
    () => set(asCtx(U.seller), 'products', 'p3', { ...prod, price: -1 }));
  await cantDo('catalog · khách KHÔNG sửa được sản phẩm',
    () => upd(asCtx(U.khach), 'products', 'p1', { price: 1 }));
  await canDo('catalog · seller thêm thông số kỹ thuật',
    () => set(asCtx(U.seller), 'products', 'p1', 'specs', 'ram', { value: '8GB' }));
}

/* ============================================================
   NHÓM B (mở rộng) — validate danh mục, giới hạn ảnh, thông số
   Đây là các Rules siết thêm cho Phase 4 (CRUD danh mục + upload
   ảnh base64 + validate trước khi ghi). Ngưỡng phải khớp hằng số
   trong client/lib/core/validation.dart.
   ============================================================ */
async function testCatalogValidation() {
  const seller = asCtx(U.seller);
  const khach = asCtx(U.khach);
  const cat = (over) => ({
    name: 'Dien thoai', sort_order: 1, is_active: true,
    created_at: NOW(), deleted_at: null, ...over
  });
  const prod = (over) => ({
    category_id: 'dien-thoai', sku: 'IP15P', name: 'iPhone 15 Pro Max',
    description: 'dien thoai', price: 27390000, image_data: 'AA',
    is_available: true, embedding: [], sort_order: 1,
    created_at: NOW(), updated_at: NOW(), deleted_at: null, ...over
  });

  /* ---- danh mục ---- */
  await canDo('catalog · seller tạo danh mục hợp lệ',
    () => set(seller, 'categories', 'dien-thoai', cat()));
  await cantDo('catalog · danh mục tên rỗng bị chặn',
    () => set(seller, 'categories', 'c-rong', cat({ name: '' })));
  await cantDo('catalog · danh mục thiếu name bị chặn',
    () => set(seller, 'categories', 'c-thieu',
      { sort_order: 1, is_active: true, created_at: NOW() }));
  await cantDo('catalog · danh mục tên quá 60 ký tự bị chặn',
    () => set(seller, 'categories', 'c-dai', cat({ name: 'x'.repeat(61) })));
  await cantDo('catalog · danh mục sort_order âm bị chặn',
    () => set(seller, 'categories', 'c-am', cat({ sort_order: -1 })));
  await cantDo('catalog · khách KHÔNG tạo được danh mục',
    () => set(khach, 'categories', 'c-khach', cat()));
  await canDo('catalog · seller đổi tên danh mục',
    () => upd(seller, 'categories', 'dien-thoai',
      { name: 'Dien thoai & Tablet', updated_at: NOW() }));
  await canDo('catalog · seller ẩn danh mục (xoá mềm)',
    () => upd(seller, 'categories', 'dien-thoai', { deleted_at: NOW() }));
  await canDo('catalog · storefront công khai vẫn đọc được danh mục',
    () => get(testEnv.unauthenticatedContext().firestore(), 'categories', 'dien-thoai'));

  /* ---- sản phẩm: trần độ dài và giới hạn 1 MiB của Firestore ---- */
  await canDo('catalog · tạo sản phẩm khi ảnh nằm ngay dưới ngưỡng 700000 ký tự',
    () => set(seller, 'products', 'p-anh', prod({ image_data: 'x'.repeat(699999) })));
  await cantDo('catalog · ảnh vượt ngưỡng (lỗi Firestore 1 MiB/doc) bị chặn',
    () => set(seller, 'products', 'p-anh-lon', prod({ image_data: 'x'.repeat(700001) })));
  await cantDo('catalog · tên sản phẩm quá 120 ký tự bị chặn',
    () => set(seller, 'products', 'p-ten-dai', prod({ name: 'x'.repeat(121) })));
  await cantDo('catalog · SKU rỗng bị chặn',
    () => set(seller, 'products', 'p-sku-rong', prod({ sku: '' })));
  await cantDo('catalog · SKU quá 40 ký tự bị chặn',
    () => set(seller, 'products', 'p-sku-dai', prod({ sku: 'x'.repeat(41) })));
  await cantDo('catalog · image_data không phải chuỗi bị chặn',
    () => set(seller, 'products', 'p-anh-so', prod({ image_data: 123 })));

  /* ---- thông số kỹ thuật ---- */
  await canDo('catalog · ghi thông số giá trị ngắn',
    () => set(seller, 'products', 'p1', 'specs', 'rom', { value: '256GB' }));
  await cantDo('catalog · thông số vượt 120 ký tự bị chặn',
    () => set(seller, 'products', 'p1', 'specs', 'rom-dai',
      { value: 'x'.repeat(121) }));
  await cantDo('catalog · thông số thiếu value bị chặn',
    () => set(seller, 'products', 'p1', 'specs', 'khong-co-value', {}));
  await cantDo('catalog · khách KHÔNG sửa được thông số',
    () => upd(khach, 'products', 'p1', 'specs', 'ram', { value: '999GB' }));
  await canDo('catalog · seller xoá được thông số đã gỡ trên form',
    () => del(seller, 'products', 'p1', 'specs', 'rom'));

  /* ---- luồng tạo sản phẩm kèm nhập kho: phải ghi kèm stock_movements ----
     Nếu client tạo sản phẩm mà không ghi dòng nhật ký thì tổng nhập xuất
     lệch với tồn và admin mất cách đối chiếu. Rules chặn việc tạo movement
     thiếu lý do / actor, nên dòng này bảo đảm đường ghi đó còn nguyên.

     docID cố tình đặt tiền tố khác với nhóm testStockMovements bên dưới:
     `stock_movements` có `allow update: if false`, nên nếu hai nhóm dùng
     chung một docID thì lần ghi thứ hai thành update và luôn bị chặn —
     phép thử đỏ vì va chạm dữ liệu chứ không phải vì Rules sai. */
  await canDo('catalog · seller ghi dòng nhập kho kèm lý do và người thao tác',
    () => set(seller, 'stock_movements', 'v-purchase', {
      product_id: 'p1', type: 'purchase', quantity: 50,
      reason: 'Nhap kho ban dau', actor_id: U.seller,
      created_at: NOW()
    }));
  await cantDo('catalog · movement thiếu lý do bị chặn',
    () => set(seller, 'stock_movements', 'v-no-reason', {
      product_id: 'p1', type: 'purchase', quantity: 50,
      actor_id: U.seller, created_at: NOW()
    }));
  await cantDo('catalog · movement ghi thay người khác bị chặn',
    () => set(seller, 'stock_movements', 'v-no-actor', {
      product_id: 'p1', type: 'purchase', quantity: 50,
      reason: 'x', actor_id: U.admin, created_at: NOW()
    }));
  await cantDo('catalog · movement số lượng bằng 0 bị chặn',
    () => set(seller, 'stock_movements', 'v-zero', {
      product_id: 'p1', type: 'purchase', quantity: 0,
      reason: 'x', actor_id: U.seller, created_at: NOW()
    }));
  await cantDo('catalog · movement sai loại bị chặn',
    () => set(seller, 'stock_movements', 'v-sai-loai', {
      product_id: 'p1', type: 'xoa-hang', quantity: 5,
      reason: 'x', actor_id: U.seller, created_at: NOW()
    }));
}

/* ============================================================
   NHÓM C — kho: bất biến hiệu chống bơm tồn
   ============================================================ */
async function testInventory() {
  const inv = (onHand, reserved, avail) => ({
    product_id: 'p1', stock_on_hand: onHand, stock_reserved: reserved,
    stock_available: avail, updated_at: NOW()
  });
  const updInv = (a, r, v) => upd(asCtx(U.seller), 'inventory', 'p1', inv(a, r, v));

  await canDo('inventory · seller khởi tạo tồn kho',
    () => set(asCtx(U.seller), 'inventory', 'p1', inv(100, 0, 100)));
  await canDo('inventory · đọc public (số tồn ở storefront khi chưa đăng nhập)',
    () => get(testEnv.unauthenticatedContext().firestore(), 'inventory', 'p1'));
  await cantDo('inventory · khách KHÔNG ghi được tồn kho',
    () => set(asCtx(U.khach), 'inventory', 'p2', inv(10, 0, 10)));

  /* ---- các nghiệp vụ hợp lệ: bất biến hiệu phải cho qua ---- */
  await canDo('inventory · nhập kho +20 hợp lệ (available +20)',
    () => updInv(120, 0, 120));
  await canDo('inventory · reserve 5 hợp lệ (available −5)',
    () => updInv(120, 5, 115));
  await canDo('inventory · bán/deduct 5 hợp lệ (available giữ nguyên)',
    () => updInv(115, 0, 115));
  await canDo('inventory · release 3 hợp lệ (available +3)',
    () => updInv(115, 3, 112));

  /* ---- thao tác gian lận ---- */
  await cantDo('inventory · CHẶN bơm stock_available để lách chống oversell',
    () => updInv(115, 3, 9999));
  await cantDo('inventory · CHẶN giữ nguyên available trong khi đã reserve',
    () => updInv(115, 3, 115));
  await cantDo('inventory · tồn âm bị chặn',
    () => updInv(-5, 0, 0));
  await cantDo('inventory · reserved > on_hand bị chặn',
    () => updInv(10, 20, 0));
  await cantDo('inventory · available âm bị chặn',
    () => updInv(10, 0, -1));
}

async function testStockMovements() {
  const mv = over => ({
    product_id: 'p1', type: 'purchase', quantity: 20, reference_id: null,
    reason: 'Nhap hang tu nha cung cap', actor_id: U.seller,
    created_at: NOW(), ...over
  });

  await cantDo('stock_movements · khách KHÔNG ghi được nhật ký tồn',
    () => set(asCtx(U.khach), 'stock_movements', 'm1', mv({})));
  await canDo('stock_movements · seller ghi được biến động tồn',
    () => set(asCtx(U.seller), 'stock_movements', 'm1', mv({})));
  await cantDo('stock_movements · thiếu lý do bị chặn',
    () => set(asCtx(U.seller), 'stock_movements', 'm2', mv({ reason: '' })));
  await cantDo('stock_movements · số lượng 0 bị chặn',
    () => set(asCtx(U.seller), 'stock_movements', 'm3', mv({ quantity: 0 })));
  await cantDo('stock_movements · KHÔNG ghi log hộ người khác',
    () => set(asCtx(U.seller), 'stock_movements', 'm4', mv({ actor_id: U.admin })));
  await cantDo('stock_movements · KHÔNG sửa được nhật ký (bất biến)',
    () => upd(asCtx(U.admin), 'stock_movements', 'm1', { reason: 'doi ly do' }));
  await cantDo('stock_movements · KHÔNG xoá được nhật ký (bất biến)',
    () => del(asCtx(U.admin), 'stock_movements', 'm1'));
}

/* ============================================================
   NHÓM D — giỏ hàng, đơn, state machine
   ============================================================ */
async function testCart() {
  const line = { quantity: 2, created_at: NOW() };
  const C = ['users', U.khach, 'carts', 'active'];

  await canDo('cart · khách tạo được giỏ active',
    () => set(asCtx(U.khach), ...C, { status: 'active', created_at: NOW() }));
  await canDo('cart · khách thêm sản phẩm vào giỏ',
    () => set(asCtx(U.khach), ...C, 'items', 'p1', line));
  await cantDo('cart · số lượng 0 bị chặn',
    () => set(asCtx(U.khach), ...C, 'items', 'p2', { quantity: 0, created_at: NOW() }));
  await cantDo('cart · KHÔNG ghi được vào giỏ người khác',
    () => set(asCtx(U.khach3), ...C, 'items', 'p3', line));
}

async function testOrders() {
  await canDo('orders · khách đặt được đơn cho chính mình',
    () => set(asCtx(U.khach), 'orders', 'K1', orderDoc(U.khach)));
  await cantDo('orders · KHÔNG đặt được đơn mang tên người khác',
    () => set(asCtx(U.khach3), 'orders', 'K2', orderDoc(U.khach)));
  await cantDo('orders · khách KHÔNG tạo được đơn khác trạng thái pending',
    () => set(asCtx(U.khach), 'orders', 'K3', orderDoc(U.khach, { status: 'confirmed' })));
  await cantDo('orders · tổng tiền phải khớp subtotal + phí giao',
    () => set(asCtx(U.khach), 'orders', 'K4', orderDoc(U.khach, { total: 999 })));

  /* quyền đọc */
  await canDo('orders · chủ đơn đọc được',
    () => get(asCtx(U.khach), 'orders', 'K1'));
  await cantDo('orders · khách KHÔNG đọc được đơn người khác',
    () => get(asCtx(U.khach3), 'orders', 'K1'));
  await canDo('orders · seller đọc được mọi đơn của cửa hàng',
    () => get(asCtx(U.seller), 'orders', 'K1'));
  await cantDo('orders · người văng KHÔNG đọc được đơn',
    () => get(testEnv.unauthenticatedContext().firestore(), 'orders', 'K1'));

  /* state machine đúng 6 bước */
  const go = (uid, to, over = {}) =>
    upd(asCtx(uid), 'orders', 'K1', orderDoc(U.khach, { status: to, ...over }));
  await canDo('orders · seller xác nhận pending → confirmed', () => go(U.seller, 'confirmed'));
  await canDo('orders · seller confirmed → packing', () => go(U.seller, 'packing'));
  await canDo('orders · seller packing → shipped', () => go(U.seller, 'shipped'));
  await canDo('orders · seller shipped → delivered', () => go(U.seller, 'delivered'));
  await canDo('orders · seller delivered → completed', () => go(U.seller, 'completed'));

  /* chuyển ngược: dùng đơn MỚI vì K1 đã ở completed, mà completed là
     trạng thái kết thúc nên không quay lại được — đó chính là hành vi
     đúng, phải kiểm bằng đơn riêng cho nhánh "đã giao xong rồi quay lại". */
  const goM = (to) =>
    upd(asCtx(U.seller), 'orders', 'K8', orderDoc(U.khach, { status: to }));
  await canDo('orders · tạo đơn M8 để thử chuyển ngược', () =>
    set(asCtx(U.khach), 'orders', 'K8', orderDoc(U.khach)));
  await canDo('orders · M8 pending → confirmed', () => goM('confirmed'));
  await canDo('orders · M8 confirmed → packing', () => goM('packing'));
  await canDo('orders · M8 packing → shipped', () => goM('shipped'));
  await canDo('orders · M8 shipped → delivered', () => goM('delivered'));
  await cantDo('orders · KHÔNG chuyển ngược (delivered → packing)', () => goM('packing'));
  await cantDo('orders · KHÔNG nhảy cóc (delivered → completed chỉ qua đúng bước)',
    () => goM('pending'));
  await cantDo('orders · completed KHÔNG quay về pending', () => {
    return (async () => { await goM('completed'); await goM('pending'); })();
  });
  await cantDo('orders · bỏ qua bước (pending → delivered) bị chặn',
    () => upd(asCtx(U.seller), 'orders', 'K7', orderDoc(U.khach, { status: 'delivered' })));

  /* quyền của khách trên đơn */
  await canDo('orders · tạo đơn mới để thử quyền khách', () =>
    set(asCtx(U.khach), 'orders', 'K5', orderDoc(U.khach)));
  await cantDo('orders · khách KHÔNG tự xác nhận đơn',
    () => upd(asCtx(U.khach), 'orders', 'K5', orderDoc(U.khach, { status: 'confirmed' })));
  await cantDo('orders · khách KHÔNG tự chuyển payment_status = paid',
    () => upd(asCtx(U.khach), 'orders', 'K5', orderDoc(U.khach, { payment_status: 'paid' })));
  await cantDo('orders · hủy đơn BẮT BUỘC phải có lý do',
    () => upd(asCtx(U.khach), 'orders', 'K5', orderDoc(U.khach, { status: 'canceled' })));
  await canDo('orders · khách hủy được đơn của chính mình khi còn pending',
    () => upd(asCtx(U.khach), 'orders', 'K5',
      orderDoc(U.khach, { status: 'canceled', cancel_reason: 'Khach doi y', canceled_by: U.khach })));
  await cantDo('orders · đơn đã hủy KHÔNG quay lại pending được',
    () => upd(asCtx(U.khach), 'orders', 'K5', orderDoc(U.khach, { status: 'pending' })));
  await cantDo('orders · KHÔAI xoá được đơn (dùng để tra cứu)',
    () => del(asCtx(U.admin), 'orders', 'K1'));
}

async function testOrderSubcollections() {
  const item = { product_name: 'iPhone 15 Pro Max', unit_price: 27390000,
    quantity: 1, note: '' };

  await canDo('orders/items · tạo đơn pending', () =>
    set(asCtx(U.khach), 'orders', 'K6', orderDoc(U.khach)));
  await canDo('orders/items · khách thêm dòng hàng khi đơn còn pending',
    () => set(asCtx(U.khach), 'orders', 'K6', 'items', 'p1', item));
  await cantDo('orders/items · khách KHÔNG thêm dòng hàng vào đơn người khác',
    () => set(asCtx(U.khach3), 'orders', 'K6', 'items', 'p9', item));
  await cantDo('orders/items · số lượng 0 bị chặn',
    () => set(asCtx(U.khach), 'orders', 'K6', 'items', 'p8',
      { ...item, quantity: 0 }));

  await canDo('orders/items · seller xác nhận đơn', () =>
    upd(asCtx(U.seller), 'orders', 'K6', orderDoc(U.khach, { status: 'confirmed' })));
  await cantDo('orders/items · đơn đã xác nhận thì KHÔNG thêm dòng mới',
    () => set(asCtx(U.seller), 'orders', 'K6', 'items', 'p2', item));
  await cantDo('orders/items · KHÔNG sửa được dòng hàng đã lưu (lịch sử bất biến)',
    () => upd(asCtx(U.seller), 'orders', 'K6', 'items', 'p1', { unit_price: 1 }));

  const hist = { from_status: 'pending', to_status: 'confirmed',
    actor_id: U.seller, note: '', created_at: NOW() };
  await canDo('orders/history · ghi được nhật ký chuyển trạng thái',
    () => set(asCtx(U.seller), 'orders', 'K6', 'history', 'h1', hist));
  await cantDo('orders/history · KHÔNG sửa được',
    () => upd(asCtx(U.seller), 'orders', 'K6', 'history', 'h1', { note: 'doi' }));
  await cantDo('orders/history · KHÔNG xoá được',
    () => del(asCtx(U.seller), 'orders', 'K6', 'history', 'h1'));
  await cantDo('orders/history · KHÔNG ghi log vào đơn người khác',
    () => set(asCtx(U.khach3), 'orders', 'K6', 'history', 'h2',
      { ...hist, actor_id: U.khach3 }));
}

/* ============================================================
   NHÓM E — thanh toán: chống double-confirm
   ============================================================ */
async function testPayments() {
  await canDo('payments · tạo đơn QR trước', () =>
    set(asCtx(U.khach), 'orders', 'P1',
      orderDoc(U.khach, { payment_method: 'bank_transfer' })));
  const qr = { order_id: 'P1', method: 'bank_transfer', status: 'paid', amount: 1015000,
    bank_txn_ref: 'GD8821', created_by: U.seller, paid_at: NOW(), created_at: NOW() };

  await cantDo('payments · khách KHÔNG tự ghi nhận thanh toán',
    () => set(asCtx(U.khach), 'payments', 'P1', qr));
  await canDo('payments · seller ghi nhận thanh toán QR',
    () => set(asCtx(U.seller), 'payments', 'P1', qr));
  /* docID = orderId nên ghi lần 2 trùng doc và bị chặn — chống cộng tiền 2 lần */
  await cantDo('payments · CHẶN thanh toán kép (docID = orderId)',
    () => set(asCtx(U.seller), 'payments', 'P1', { ...qr, amount: 9999999 }));

  /* COD: bắt buộc có số tiền đã thu + ai thu + lúc thu */
  await canDo('payments · tạo đơn COD trước', () =>
    set(asCtx(U.khach), 'orders', 'P2', orderDoc(U.khach, { payment_method: 'cod' })));
  const cod = { order_id: 'P2', method: 'cod', status: 'paid', amount: 1015000,
    created_by: U.seller, paid_at: NOW(), created_at: NOW() };

  await cantDo('payments · COD chưa ghi số tiền thu bị chặn',
    () => set(asCtx(U.seller), 'payments', 'P2', cod));
  await cantDo('payments · COD thiếu collected_by / collected_at bị chặn',
    () => set(asCtx(U.seller), 'payments', 'P2',
      { ...cod, cod_collected_amount: 1015000 }));
  await canDo('payments · COD ghi đủ số tiền + người thu + thời điểm',
    () => set(asCtx(U.seller), 'payments', 'P2',
      { ...cod, cod_collected_amount: 1015000, collected_by: U.seller, collected_at: NOW() }));

  await cantDo('payments · số tiền phải khớp tổng đơn',
    () => set(asCtx(U.seller), 'payments', 'P3',
      { ...cod, order_id: 'P3', amount: 777, cod_collected_amount: 777,
        collected_by: U.seller, collected_at: NOW() }));
  await cantDo('payments · hoàn tiền phải có lý do',
    () => upd(asCtx(U.seller), 'payments', 'P2',
      { ...cod, status: 'refunded', cod_collected_amount: 1015000,
        collected_by: U.seller, collected_at: NOW() }));
}

/* ============================================================
   NHÓM F — chatbot & audit log
   ============================================================ */
async function testChat() {
  const conv = { user_id: U.khach, status: 'active', last_message_at: NOW(), created_at: NOW() };
  const msg = over => ({ role: 'user', content: 'Laptop 15 trieu co san khong?',
    sources: [], is_from_fallback: false, tokens_used: 12, created_at: NOW(), ...over });

  await canDo('chat · khách tạo được hội thoại',
    () => set(asCtx(U.khach), 'chat_conversations', 'c1', conv));
  await cantDo('chat · KHÔNG tạo được hội thoại mang tên người khác',
    () => set(asCtx(U.khach3), 'chat_conversations', 'c2', conv));
  await cantDo('chat · người có role không hợp lệ bị chặn',
    () => set(asCtx(U.hacker), 'chat_conversations', 'c3', conv));

  await canDo('chat · ghi được tin nhắn',
    () => set(asCtx(U.khach), 'chat_conversations', 'c1', 'messages', 'm1', msg({})));
  await cantDo('chat · KHÔNG ghi được vào hội thoại người khác',
    () => set(asCtx(U.khach3), 'chat_conversations', 'c1', 'messages', 'm2', msg({})));
  await cantDo('chat · tin nhắn quá dài bị chặn',
    () => set(asCtx(U.khach), 'chat_conversations', 'c1', 'messages', 'm3',
      msg({ content: 'x'.repeat(5000) })));
  await cantDo('chat · KHÔNG sửa được tin nhắn đã gửi',
    () => upd(asCtx(U.khach), 'chat_conversations', 'c1', 'messages', 'm1',
      { content: 'sua lai' }));
  await cantDo('chat · KHÔNG xoá được tin nhắn đã gửi',
    () => del(asCtx(U.khach), 'chat_conversations', 'c1', 'messages', 'm1'));
}

async function testAuditLogs() {
  const log = over => ({ user_id: U.admin, action: 'product.price_change',
    target_type: 'product', target_id: 'p1', metadata: {},
    created_at: NOW(), ...over });

  await canDo('audit · admin ghi được nhật ký',
    () => set(asCtx(U.admin), 'audit_logs', 'l1', log({})));
  await canDo('audit · seller ghi được nhật ký thao tác của chính mình',
    () => set(asCtx(U.seller), 'audit_logs', 'l2',
      log({ user_id: U.seller, action: 'order.confirm', target_type: 'order' })));
  await cantDo('audit · KHÔNG ghi log hộ người khác',
    () => set(asCtx(U.seller), 'audit_logs', 'l3', log({ user_id: U.admin })));
  await cantDo('audit · khách KHÔNG ghi được audit log',
    () => set(asCtx(U.khach), 'audit_logs', 'l4', log({ user_id: U.khach })));

  await canDo('audit · admin đọc được',
    () => get(asCtx(U.admin), 'audit_logs', 'l1'));
  await cantDo('audit · seller KHÔNG đọc được',
    () => get(asCtx(U.seller), 'audit_logs', 'l1'));
  await cantDo('audit · khách KHÔNG đọc được',
    () => get(asCtx(U.khach), 'audit_logs', 'l1'));
  await cantDo('audit · KHÔNG sửa được, kể cả admin',
    () => upd(asCtx(U.admin), 'audit_logs', 'l1', { action: 'doi' }));
  await cantDo('audit · KHÔNG xoá được, kể cả admin',
    () => del(asCtx(U.admin), 'audit_logs', 'l1'));
}

/* ============================================================
   chạy
   ============================================================ */

/* Port emulator đọc từ biến môi trường, KHÔNG hardcode.

   `firebase emulators:exec` luôn truyền FIRESTORE_EMULATOR_HOST cho lệnh
   nó bọc, nên đây là nguồn đúng. Trước đây file này ghi cứng 8888 — chỉ
   khớp với `firebase.json` ở máy dev, nên chuyển repo là vỡ ngay (repo đó
   khai báo port 8080). Bộ test không được phụ thuộc vào cấu hình của một
   máy cụ thể. */
const [emuHost, emuPort] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8888').split(':');

testEnv = await initializeTestEnvironment({
  projectId: 'demo-dhhshop',
  firestore: { rules: RULES, host: emuHost, port: Number(emuPort) }
});

/* seed bằng quyền admin của Firestore SDK (bypass Rules) */
await testEnv.withSecurityRulesDisabled(async ctx => {
  const db = ctx.firestore();
  const TS = new Date('2026-01-01T00:00:00Z');
  const at = { created_at: TS };
  await db.doc('users/' + U.khach).set({ ...userDoc(U.khach, 'customer'), ...at });
  await db.doc('users/' + U.khach2).set({ ...userDoc(U.khach2, 'customer'), ...at });
  await db.doc('users/' + U.khach3).set({ ...userDoc(U.khach3, 'customer'), ...at });
  await db.doc('users/' + U.seller).set({ ...userDoc(U.seller, 'seller'), ...at });
  await db.doc('users/' + U.admin).set({ ...userDoc(U.admin, 'admin'), ...at });
  await db.doc('users/' + U.hacker).set({ ...userDoc(U.hacker, 'hacker'), ...at });
  await db.doc('users/' + U.khac4).set({ ...userDoc(U.khac4, 'customer'), ...at });
  await db.doc('settings/store').set({ name: 'Cua hang DHH', bank_bin: '970422' });
  await db.doc('delivery_zones/ha_noi_dong_da').set({ name: 'Noi thanh', fee: 15000 });
  await db.doc('products/p1').set({
    category_id: 'dien-thoai', sku: 'IP15P', name: 'iPhone 15 Pro Max',
    description: 'dt', price: 27390000, image_data: 'x', is_available: true,
    embedding: [], sort_order: 1, created_at: TS, updated_at: TS, deleted_at: null });
  await db.doc('inventory/p1').set({ product_id: 'p1', stock_on_hand: 100,
    stock_reserved: 0, stock_available: 100, updated_at: TS });
  await db.doc('stock_movements/seed').set({ product_id: 'p1', type: 'purchase',
    quantity: 100, reason: 'seed', actor_id: U.admin, created_at: TS });
  await db.doc('orders/OLD').set({ ...orderDoc(U.khach), created_at: TS });
  await db.doc('payments/OLD').set({ order_id: 'OLD', method: 'cod', status: 'paid',
    amount: 1015000, cod_collected_amount: 1015000, collected_by: U.seller,
    collected_at: TS, created_at: TS });
});

const SUITES = [
  ['Nhóm A · users + phân quyền', testUsers],
  ['Nhóm A · sổ địa chỉ', testAddresses],
  ['Nhóm A · settings + delivery_zones', testSettingsAndZones],
  ['Nhóm B · catalog', testCatalog],
  ['Nhóm B · catalog — validate danh mục / ảnh / thông số', testCatalogValidation],
  ['Nhóm C · inventory — bất biến hiệu', testInventory],
  ['Nhóm C · stock_movements', testStockMovements],
  ['Nhóm D · giỏ hàng', testCart],
  ['Nhóm D · đơn + state machine', testOrders],
  ['Nhóm D · items + history', testOrderSubcollections],
  ['Nhóm E · payments — chống kép', testPayments],
  ['Nhóm F · chatbot', testChat],
  ['Nhóm F · audit log', testAuditLogs]
];

let last = '';
for (const [title, fn] of SUITES) {
  const before = results.length;
  try { await fn(); }
  catch (e) { results.push({ name: title + ' → LỖI NGOẶE', ok: false, detail: short(e) }); }
  const bad = results.slice(before).filter(r => !r.ok).length;
  const label = (title + '                              ').slice(0, 42);
  console.log(label + (bad ? `  ${bad} LỖI` : '  ok'));
  last = title;
}

const bad = results.filter(r => !r.ok);
console.log('\n══════════════════════════════════════════════');
console.log(`KẾT QUẢ: ${results.length - bad.length}/${results.length} phép thử đạt`);
if (bad.length) {
  console.log('\nCÁC PHÉP THỬ KHÔNG ĐẠT:');
  bad.forEach(r => console.log('  x ' + r.name + (r.detail ? '\n      ' + r.detail : '')));
}
console.log('');
await testEnv.cleanup();
process.exit(bad.length ? 1 : 0);
