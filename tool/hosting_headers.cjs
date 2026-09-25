const assert = require('node:assert/strict');
(async () => {
  for (const file of ['/', '/index.html', '/main.dart.js', '/flutter_bootstrap.js',
    '/flutter_service_worker.js', '/version.json', '/release.json', '/app-update.js', '/test-route']) {
    const response = await fetch('http://127.0.0.1:5000' + file, {method:'HEAD'});
    assert.equal(response.status, 200, file);
    assert.equal(response.headers.get('cache-control'), 'no-cache, no-store, must-revalidate', file);
    console.log('PASS no-store ' + file);
  }
})().catch(error => {console.error(error); process.exitCode=1;});
