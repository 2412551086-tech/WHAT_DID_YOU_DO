import { chmodSync, copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { createPrivateKey, randomBytes } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Run on the server. Never print key material or production environment values.
const directory = dirname(fileURLToPath(import.meta.url));
const source = process.argv[2];
if (!source || !existsSync(source)) throw new Error('Provide the downloaded .p8 file path');
const key = createPrivateKey(readFileSync(source));
if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
  throw new Error('Expected an Apple P-256 private key');
}
const envPath = resolve(directory, 'production.env');
const original = readFileSync(envPath, 'utf8');
const secretDir = resolve(directory, '.secrets');
mkdirSync(secretDir, { recursive: true, mode: 0o700 });
chmodSync(secretDir, 0o700);
const keyPath = resolve(secretDir, 'apple-login.p8');
if (existsSync(keyPath) && !readFileSync(keyPath).equals(readFileSync(source))) {
  throw new Error('A different Apple key is already installed; do not rotate implicitly');
}
if (resolve(source) !== keyPath) copyFileSync(source, keyPath);
chmodSync(keyPath, 0o600);
const existing = original.match(/^APPLE_TOKEN_ENCRYPTION_KEY=([a-f0-9]{64})\s*$/mi)?.[1];
if (/^APPLE_TOKEN_ENCRYPTION_KEY=/m.test(original) && !existing) {
  throw new Error('Existing Apple encryption key is invalid; investigate without overwriting');
}
const values = {
  APPLE_CLIENT_ID: 'com.douxiaolang.familyguard',
  APPLE_TEAM_ID: '3WY4649N39',
  APPLE_KEY_ID: 'F92P7M35DU',
  APPLE_PRIVATE_KEY_PATH: '/run/familyguard-secrets/apple-login.p8',
  APPLE_TOKEN_ENCRYPTION_KEY: existing ?? randomBytes(32).toString('hex'),
};
let updated = original;
for (const [name, value] of Object.entries(values)) {
  const line = `${name}=${value}`;
  const pattern = new RegExp(`^${name}=.*$`, 'm');
  updated = pattern.test(updated) ? updated.replace(pattern, line) : `${updated.trimEnd()}\n${line}\n`;
}
const temporary = `${envPath}.apple.tmp`;
writeFileSync(temporary, updated, { mode: 0o600 });
chmodSync(temporary, 0o600);
renameSync(temporary, envPath);
console.log('Apple login configuration installed; secrets were not printed.');
