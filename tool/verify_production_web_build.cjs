const path = require('node:path');

const {verifyProductionRelease} = require('./production_release_config.cjs');

const config = verifyProductionRelease({
  buildDirectory: path.resolve(__dirname, '../build/web'),
});
console.log(`PASS verified web artifact for ${config.collectorBackendUrl}`);
