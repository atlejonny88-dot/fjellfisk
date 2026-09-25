const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function prepare(directory) {
  const indexPath = path.join(directory, 'index.html');
  let index = fs.readFileSync(indexPath, 'utf8');
  const marker = /(<meta name="fjellfisk-build" content=")[^"]*(">)/;
  if (!marker.test(index)) throw new Error('Missing build marker. Rebuild Flutter web first.');
  const hash = crypto.createHash('sha256');
  // Hash the delivered files, including assets, so asset-only releases are detected.
  function visit(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const file = path.join(dir, entry.name);
      if (entry.isDirectory()) { visit(file); continue; }
      const relative = path.relative(directory, file).replaceAll('\\', '/');
      if (relative === 'release.json') continue;
      const data = relative === 'index.html'
        ? index.replace(marker, '$1__FJELLFISK_BUILD_ID__$2')
        : fs.readFileSync(file);
      hash.update(relative + '\0');
      hash.update(data);
      hash.update('\0');
    }
  }
  visit(directory);
  const buildId = hash.digest('hex');
  index = index.replace(marker, '$1' + buildId + '$2');
  fs.writeFileSync(indexPath, index);
  fs.writeFileSync(path.join(directory, 'release.json'), JSON.stringify({ buildId }) + '\n');
  return buildId;
}

if (require.main === module) {
  console.log('Prepared Fjellfisk web build: ' + prepare(path.resolve(__dirname, '../build/web')));
}
module.exports = { prepare };
