// Read-only release smoke. Requires Playwright via NODE_PATH or local tooling.
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../build/web');
const output = path.resolve(__dirname, '../build/qa');
fs.mkdirSync(output, {recursive: true});
const oldId = 'a'.repeat(64), newId = 'b'.repeat(64);
let published = oldId;
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  if (url.pathname === '/update-fixture.html') {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.end(`<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="fjellfisk-build" content="${oldId}"><script src="app-update.js" defer></script>`);
  }
  if (url.pathname === '/release.json' && url.searchParams.has('fixture')) {
    res.setHeader('Content-Type', 'application/json');
    return res.end(JSON.stringify({buildId: published}));
  }
  const target = path.resolve(root, '.' + decodeURIComponent(url.pathname));
  if (!target.startsWith(root + path.sep) && target !== root) {
    res.writeHead(403); return res.end();
  }
  const file = fs.existsSync(target) && fs.statSync(target).isFile() ? target : path.join(root, 'index.html');
  const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.json':'application/json',
    '.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf'};
  res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const errors = [];
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    page.on('response', response => {
      if (response.url().startsWith(base) && response.status() >= 400) errors.push(response.url() + ' ' + response.status());
    });
    for (const [name, width, height] of [['desktop',1440,1000], ['mobile',390,844]]) {
      await page.setViewportSize({width,height});
      await page.goto(base, {waitUntil: 'networkidle'});
      const semantics = page.locator('flt-semantics-placeholder');
      if (await semantics.count()) await semantics.evaluate(el => el.click());
      await page.getByRole('button', {name: 'Logg inn', exact: true}).waitFor({timeout: 45000});
      await page.screenshot({path: path.join(output, `login-${name}.png`)});
      await page.reload({waitUntil: 'networkidle'});
    }
    assert.deepEqual(errors, [], 'Release browser errors');
    console.log('PASS release login, desktop/mobile, refresh, assets and JS errors');
    await context.close();

    const updates = await browser.newContext({viewport: {width:390,height:844}});
    const u = await updates.newPage();
    await u.route('**/release.json?*', route => route.fulfill({contentType:'application/json', body:JSON.stringify({buildId:published})}));
    await u.clock.install();
    await u.goto(base+'/update-fixture.html?keep=yes#/tank/test');
    await u.evaluate(() => localStorage.setItem('auth-preservation-sentinel','keep'));
    await u.clock.fastForward(16000);
    assert.equal(await u.locator('#fjellfisk-update').count(), 0);
    published = newId;
    await u.clock.fastForward(300000);
    await u.getByRole('button',{name:'Oppdater nå'}).waitFor();
    await u.screenshot({path:path.join(output,'update-mobile.png')});
    await u.evaluate(() => {window.fjellfiskSaving=true;});
    await u.getByRole('button',{name:'Oppdater nå'}).click();
    assert.ok(await u.getByText('Vent til registreringen er ferdig lagret før du oppdaterer.').isVisible());
    await u.evaluate(() => {window.fjellfiskSaving=false;});
    u.once('dialog', dialog => dialog.accept());
    await Promise.all([u.waitForURL(url => url.searchParams.get('fjellfisk_build') === newId),u.getByRole('button',{name:'Oppdater nå'}).click()]);
    assert.ok(u.url().endsWith('#/tank/test'));
    assert.ok(u.url().includes('keep=yes'));
    assert.equal(await u.evaluate(() => localStorage.getItem('auth-preservation-sentinel')), 'keep');
    await updates.close();
    console.log('PASS old/new banner, save guard, reload URL and stored-session preservation');
  } finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
})().catch(error => {console.error(error); server.close(); process.exitCode=1;});
