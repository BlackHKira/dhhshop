// Seed catalog mở rộng lên Firestore PRODUCTION bằng Admin SDK.
// Idempotent theo slug: chỉ thêm 92 SP mới, KHÔNG đụng 8 SP legacy.
//
//   node scripts/seed_catalog_extend.mjs \
//       --service-account C:\path\key.json \
//       --project hddshop-bea07 \
//       --images-dir C:\temp\catalog_img \
//       [--dry-run] [--no-images] [--limit N] [--skip-backup]
//
// - Backup catalog hiện tại ra JSON trước khi ghi (trừ --skip-backup).
// - categories: set(merge) 11 danh mục.
// - products: set(merge) 92 SP; created_at CHỈ ghi khi doc chưa tồn tại.
// - specs: WriteBatch <=400 ops.
// - inventory: set(merge) {productId}.
// - Verify: đếm products/inventory/categories, assert mọi product có inventory khớp.
//
// Mô hình dữ liệu: đồ án chỉ có MỘT cửa hàng nên không doc nào mang
// `store_id`, `inventory` đánh docID bằng productId, và xoá mềm dùng
// `deleted_at` (null = còn bán).

import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(new URL('../functions/package.json', import.meta.url));
const admin = require('firebase-admin');
const { CATEGORIES, NEW_PRODUCTS, LEGACY_SLUGS } = await import('./catalog_data.mjs');

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = {
    serviceAccount: process.env.GOOGLE_APPLICATION_CREDENTIALS ?? null,
    project: 'hddshop-bea07',
    imagesDir: path.resolve(__dirname, '..', '..', 'catalog_img'),
    dryRun: false,
    noImages: false,
    limit: 0,
    skipBackup: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--service-account') args.serviceAccount = argv[i + 1];
    if (argv[i] === '--project') args.project = argv[i + 1];
    if (argv[i] === '--images-dir') args.imagesDir = argv[i + 1];
    if (argv[i] === '--dry-run') args.dryRun = true;
    if (argv[i] === '--no-images') args.noImages = true;
    if (argv[i] === '--limit') args.limit = Number(argv[i + 1]);
    if (argv[i] === '--skip-backup') args.skipBackup = true;
  }
  return args;
}

function readImageBase64(imagesDir, slug) {
  const file = path.join(imagesDir, `${slug}.jpg`);
  if (!fs.existsSync(file)) return '';
  return fs.readFileSync(file).toString('base64');
}

async function backup(db, project) {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outFile = path.resolve(__dirname, '..', '..', `catalog_backup_${project}_${stamp}.json`);
  const [products, inventory, categories] = await Promise.all([
    db.collection('products').get(),
    db.collection('inventory').get(),
    db.collection('categories').get(),
  ]);
  const dump = {
    products: Object.fromEntries(products.docs.map((d) => [d.id, d.data()])),
    inventory: Object.fromEntries(inventory.docs.map((d) => [d.id, d.data()])),
    categories: Object.fromEntries(categories.docs.map((d) => [d.id, d.data()])),
  };
  fs.writeFileSync(outFile, JSON.stringify(dump, null, 2));
  console.log(`Backup: ${outFile} (products=${products.size}, inventory=${inventory.size}, categories=${categories.size})`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.serviceAccount) {
    console.error('Thiếu --service-account hoặc $GOOGLE_APPLICATION_CREDENTIALS');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(args.serviceAccount)),
    projectId: args.project,
  });
  const db = admin.firestore();
  const now = () => admin.firestore.FieldValue.serverTimestamp();

  let products = NEW_PRODUCTS;
  if (args.limit > 0) products = products.slice(0, args.limit);
  console.log(`Seed ${products.length} SP mới (limit=${args.limit || 'all'}) vào project ${args.project}`);

  if (!args.skipBackup && !args.dryRun) await backup(db, args.project);

  // ── categories ────────────────────────────────────────────────
  for (const c of CATEGORIES) {
    const data = { name: c.name, sort_order: c.sort_order, is_active: true, deleted_at: null };
    if (args.dryRun) {
      console.log(`[dry] categories/${c.slug} <- ${JSON.stringify(data)}`);
    } else {
      await db.collection('categories').doc(c.slug).set(data, { merge: true });
    }
  }

  // ── products + specs + inventory (batch) ──────────────────────
  const ops = [];
  const existing = new Set();

  for (const p of products) {
    const ref = db.collection('products').doc(p.slug);
    let snap = null;
    if (!args.dryRun) snap = await ref.get();
    const isNew = !snap || !snap.exists;
    existing.add(p.slug);

    const data = {
      category_id: p.category,
      sku: p.sku,
      name: p.name,
      description: p.description,
      price: p.price,
      image_data: args.noImages ? '' : readImageBase64(args.imagesDir, p.slug),
      is_available: true,
      deleted_at: null,
      sort_order: 0,
      embedding: [],
      updated_at: now(),
    };
    if (isNew) data.created_at = now();

    ops.push({ type: 'product', ref, data });

    for (const [k, v] of Object.entries(p.specs)) {
      ops.push({ type: 'spec', ref: ref.collection('specs').doc(k), data: { value: v } });
    }

    ops.push({
      type: 'inventory',
      ref: db.collection('inventory').doc(p.slug),
      data: {
        product_id: p.slug,
        stock_on_hand: p.stock,
        stock_reserved: 0,
        stock_available: p.stock,
        updated_at: now(),
      },
    });
  }

  if (args.dryRun) {
    const nProd = ops.filter((o) => o.type === 'product').length;
    const nSpec = ops.filter((o) => o.type === 'spec').length;
    const nInv = ops.filter((o) => o.type === 'inventory').length;
    console.log(`[dry-run] Sẽ ghi: ${nProd} products, ${nSpec} specs, ${nInv} inventory, ${CATEGORIES.length} categories`);
    console.log('[dry-run] Không ghi gì thật.');
    return;
  }

  // chia batch <=400 ops
  const BATCH = 400;
  let done = 0;
  for (let i = 0; i < ops.length; i += BATCH) {
    const chunk = ops.slice(i, i + BATCH);
    const batch = db.batch();
    for (const op of chunk) {
      if (op.type === 'product') batch.set(op.ref, op.data, { merge: true });
      else if (op.type === 'spec') batch.set(op.ref, op.data);
      else batch.set(op.ref, op.data, { merge: true });
    }
    await batch.commit();
    done += chunk.length;
    console.log(`  batch: ${done}/${ops.length} ops`);
  }

  // ── verify ────────────────────────────────────────────────────
  const [pCount, iCount, cCount] = await Promise.all([
    db.collection('products').get(),
    db.collection('inventory').get(),
    db.collection('categories').get(),
  ]);

  const invIds = new Set(iCount.docs.map((d) => d.id));
  const missing = [];
  for (const d of pCount.docs) {
    if (!invIds.has(d.id)) missing.push(d.id);
  }

  console.log(`\nVERIFY: products=${pCount.size} inventory=${iCount.size} categories=${cCount.size}`);
  console.log(`  legacy giữ nguyên: ${LEGACY_SLUGS.length} SP`);
  console.log(`  tổng products dự kiến: ${LEGACY_SLUGS.length + products.length}`);
  if (missing.length) {
    console.log(`  ⚠ THIẾU inventory cho: ${missing.join(', ')}`);
  } else {
    console.log('  ✓ mọi product đều có inventory khớp');
  }

  // kiểm tra ảnh
  let withImage = 0;
  let noImage = 0;
  for (const d of pCount.docs) {
    const len = (d.data().image_data || '').length;
    if (len > 0) withImage += 1; else noImage += 1;
  }
  console.log(`  ảnh: ${withImage} có ảnh, ${noImage} không ảnh (placeholder/trống)`);
}

main().catch((e) => {
  console.error('Seed lỗi:', e.stack || e.message);
  process.exit(1);
});
