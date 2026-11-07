import assert from 'node:assert/strict';
import test from 'node:test';

import {
  digestWithPepper,
  generateDeviceCredential,
  generatePairingCode,
  normalizePairingCode,
} from '../src/pairing/crypto.js';

test('pairing code is human-safe and normalizes whitespace and casing', () => {
  const code = generatePairingCode();
  assert.match(code, /^FJ-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}(?:-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}){2}$/);
  assert.equal(normalizePairingCode(`  ${code.toLowerCase().replaceAll('-', ' ')} `), code.replaceAll('-', ''));
  assert.equal(normalizePairingCode('FJ-OOOO-1111-LLLL'), null);
});

test('credentials are 256-bit random values and digests are purpose-separated', () => {
  const first = generateDeviceCredential();
  const second = generateDeviceCredential();
  assert.notEqual(first, second);
  assert.ok(Buffer.from(first, 'base64url').length >= 32);
  assert.notEqual(
    digestWithPepper('test-only-pepper-value', 'credential', first),
    digestWithPepper('test-only-pepper-value', 'pairing-code', first),
  );
});
