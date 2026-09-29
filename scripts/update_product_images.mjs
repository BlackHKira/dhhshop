// Cập nhật ảnh thật (base64) cho 8 sản phẩm trên Firestore PRODUCTION.
// Ảnh đã được nén JPEG ≤800px tại <images-dir>/<slug>.jpg.
//
//   node scripts/update_product_images.mjs \
//       --service-account C:\path\key.json \
//       --project hddshop-bea07 \
//       --images-dir C:\temp\photos_final

import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const require = createRequire(new URL('../functions/package.json', import.meta.url));
const admin = require('firebase-admin');

const PRODUCT_SLUGS = [
  'iphone-15-pro-max',
  'galaxy-s24-ultra',
  'macbook-air-m2',
  'dell-xps-13',
  'airpods-pro-2',
  'sac-gan-65w',
  'pin-du-phong-10000',
  'ban-phim-co-a87',
];

function parseArgs(argv) {
  const args = { serviceAccount: process.env.GOOGLE_APPLICATION_CREDENTIALS ?? null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag === '--project') args.project = value;
    if (flag === '--service-account') args.serviceAccount = value;
    if (flag === '--images-dir') args.imagesDir = value;
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const project = args.project ?? 'hddshop-bea07';
  if (!args.serviceAccount || !args.imagesDir) {
    console.error('Thiếu --service-account hoặc --images-dir');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(args.serviceAccount)),
    projectId: project,
  });
  const db = admin.firestore();
  const now = () => admin.firestore.FieldValue.serverTimestamp();

  let updated = 0;
  for (const slug of PRODUCT_SLUGS) {
    const file = path.join(args.imagesDir, `${slug}.jpg`);
    if (!fs.existsSync(file)) {
      console.log(`✗ thiếu ảnh: ${slug}.jpg`);
      continue;
    }
    const bytes = fs.readFileSync(file);
    if (bytes.length > 800 * 1024) {
      console.log(`✗ ảnh quá lớn, bỏ qua: ${slug}.jpg (${bytes.length})`);
      continue;
    }
    const ref = db.collection('products').doc(slug);
    if (!(await ref.get()).exists) {
      console.log(`✗ không có sản phẩm ${slug}`);
      continue;
    }
    await ref.update({
      image_data: bytes.toString('base64'),
      updated_at: now(),
    });
    updated += 1;
    console.log(`✓ ${slug} -> base64 ${(bytes.length * 4) / 3 | 0} chars`);
  }
  console.log(`Đã cập nhật ảnh cho ${updated}/${PRODUCT_SLUGS.length} sản phẩm.`);
}

main().catch((error) => {
  console.error('Lỗi:', error.message);
  process.exit(1);
});