const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.join(__dirname, '..');

test('PWA startup keeps its service worker and runtime caches intact', () => {
  const html = fs.readFileSync(path.join(root, 'web', 'index.html'), 'utf8');
  assert.match(html, /src="flutter_bootstrap\.js"/);
  assert.doesNotMatch(html, /clearFlutterCaches|clearServiceWorkers|unregister\(/);
});

test('manifest has a stable root identity for installed PWA launches', () => {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(root, 'web', 'manifest.json'), 'utf8'),
  );
  assert.equal(manifest.id, '/');
  assert.equal(manifest.start_url, '/');
  assert.equal(manifest.scope, '/');
  assert.equal(manifest.display, 'standalone');
});
