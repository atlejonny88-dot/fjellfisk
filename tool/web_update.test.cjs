const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createChecker } = require('../web/app-update.js');
const { prepare } = require('./prepare_web_release.cjs');
const current = 'a'.repeat(64), newer = 'b'.repeat(64);

test('same, malformed and offline releases never prompt', async () => {
  let prompts = 0;
  for (const release of [null, {}, {buildId: current}, {buildId: 'invalid'}]) {
    await createChecker({current, read: async () => release, available: () => prompts++}).check();
  }
  await createChecker({current, read: async () => {throw Error('offline');}, available: () => prompts++}).check();
  assert.equal(prompts, 0);
});
test('new builds prompt, dismissal suppresses same build and concurrent checks coalesce', async () => {
  let calls = 0, prompts = 0;
  const checker = createChecker({current, read: async () => {calls++; return {buildId: newer};}, available: () => prompts++});
  await Promise.all([checker.check(), checker.check()]);
  assert.equal(calls, 1);
  assert.equal(prompts, 1);
  checker.dismiss(newer);
  await checker.check();
  assert.equal(prompts, 1);
});
test('build stamp is stable, includes changed assets and matches HTML', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fjellfisk-release-test-'));
  try {
    fs.writeFileSync(path.join(dir, 'index.html'), '<meta name="fjellfisk-build" content="__FJELLFISK_BUILD_ID__">');
    fs.writeFileSync(path.join(dir, 'main.dart.js'), 'app');
    const first = prepare(dir);
    assert.equal(prepare(dir), first);
    fs.writeFileSync(path.join(dir, 'image.png'), 'asset');
    const second = prepare(dir);
    assert.notEqual(second, first);
    assert.equal(JSON.parse(fs.readFileSync(path.join(dir, 'release.json'))).buildId, second);
    assert.ok(fs.readFileSync(path.join(dir, 'index.html'), 'utf8').includes(second));
  } finally { fs.rmSync(dir, {recursive: true}); }
});
