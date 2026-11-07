const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  readProductionReleaseConfig,
  validateCollectorBackendUrl,
  verifyVaconProductionExclusion,
  verifyWebArtifact,
} = require('./production_release_config.cjs');

test('accepts the configured production Collector endpoint', () => {
  const config = readProductionReleaseConfig();
  assert.equal(config.firebaseProjectId, 'trolltungaarctictrout');
  assert.equal(config.collectorBackendUrl, 'https://api.tosprotein.com');
  assert.equal(config.vaconControlEnabled, false);
});

test('rejects a production Add-ons route to VACON', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'fjellfisk-vacon-'));
  const addOnsPath = path.join(directory, 'addons_screen.dart');
  const firebaseConfigPath = path.join(directory, 'firebase.json');
  try {
    fs.writeFileSync(addOnsPath, "import 'vacon_control_screen.dart';");
    fs.writeFileSync(firebaseConfigPath, '{}');
    assert.throws(() =>
      verifyVaconProductionExclusion({addOnsPath, firebaseConfigPath}),
    );
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});

for (const [label, value] of [
  ['missing', undefined],
  ['empty', ''],
  ['non-HTTPS', 'http://api.tosprotein.com'],
  ['localhost', 'https://localhost:8080'],
  ['loopback', 'https://127.0.0.1:8080'],
  ['emulator', 'https://firestore-emulator.local'],
]) {
  test(`rejects ${label} Collector endpoint`, () => {
    assert.throws(() => validateCollectorBackendUrl(value));
  });
}

test('web artifact verification requires the configured backend URL', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'fjellfisk-web-'));
  try {
    fs.writeFileSync(path.join(directory, 'main.dart.js'), 'https://api.tosprotein.com');
    assert.doesNotThrow(() =>
      verifyWebArtifact(directory, 'https://api.tosprotein.com'),
    );
    fs.writeFileSync(path.join(directory, 'main.dart.js'), 'missing define');
    assert.throws(() =>
      verifyWebArtifact(directory, 'https://api.tosprotein.com'),
    );
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});
