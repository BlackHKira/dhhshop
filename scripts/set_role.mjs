// Gán role (custom claim) cho user bằng Admin SDK — client KHÔNG tự đặt được claims.
// Cần firebase-admin (đã có trong functions/):
//   node scripts/set_role.mjs --email seller@demo.com --role seller
//   node scripts/set_role.mjs --uid abc123 --role system_admin --service-account ./sa.json
//
// Flag:
//   --uid <uid> | --email <email>   user cần gán role
//   --role <seller|shipper|viewer|system_admin|customer>
//   --project <id>                  mặc định hddshop-bea07
//   --service-account <path.json>    nếu không có $GOOGLE_APPLICATION_CREDENTIALS

import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(new URL('../functions/package.json', import.meta.url));
const admin = require('firebase-admin');

const VALID_ROLES = new Set(['system_admin', 'customer', 'seller', 'shipper', 'viewer']);

function parseArgs(argv) {
  const args = { serviceAccount: process.env.GOOGLE_APPLICATION_CREDENTIALS ?? null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag === '--uid' || flag === '--email' || flag === '--role') args[flag.slice(2)] = value;
    if (flag === '--project') args.project = value;
    if (flag === '--service-account') args.serviceAccount = value;
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const project = args.project ?? 'hddshop-bea07';
  const role = args.role;

  if ((!args.uid && !args.email) || !role || !VALID_ROLES.has(role)) {
    console.error('Usage: node scripts/set_role.mjs --uid <uid>|--email <email> --role <valid role> [--service-account ./sa.json]');
    process.exit(1);
  }
  if (!args.serviceAccount) {
    console.error('Thiếu service-account: set --service-account ./sa.json hoặc $GOOGLE_APPLICATION_CREDENTIALS');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(args.serviceAccount)),
    projectId: project,
  });

  const findUser = args.uid
    ? admin.auth().getUser(args.uid)
    : admin.auth().getUserByEmail(args.email);

  findUser.then(async (record) => {
    const existing = record.customClaims ?? {};
    const claims = { ...existing, [role]: true };
    await admin.auth().setCustomUserClaims(record.uid, claims);
    await admin
      .firestore()
      .collection('users')
      .doc(record.uid)
      .collection('roles')
      .doc(role)
      .set({ assigned_by: 'set_role.mjs', assigned_at: admin.firestore.FieldValue.serverTimestamp() });
    console.log(`OK: ${record.email} (${record.uid}) -> ${role}`);
  }).catch((error) => {
    console.error('Lỗi:', error.message);
    process.exit(1);
  });
}

main();