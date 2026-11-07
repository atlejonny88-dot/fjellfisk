const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {test} = require('node:test');
const {
  assertProductionBackendUrl,
  assertWebBuildConfig,
  writeWebBuildConfig,
} = require('./release_config.cjs');

test('release configuration accepts only the approved HTTPS Collector backend', () => {
  assert.equal(
    assertProductionBackendUrl('https://api.tosprotein.com'),
    'https://api.tosprotein.com',
  );
  for (const invalid of ['', 'http://api.tosprotein.com', 'https://localhost:8080',
    'https://collector-emulator.invalid', 'https://other.example']) {
    assert.throws(() => assertProductionBackendUrl(invalid));
  }
});

test('web deploy validation rejects builds without a protected release stamp', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'fjellfisk-release-config-'));
  try {
    assert.throws(() => assertWebBuildConfig(directory));
    writeWebBuildConfig(directory, 'https://api.tosprotein.com');
    assert.doesNotThrow(() => assertWebBuildConfig(directory));
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});
