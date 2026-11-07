const fs = require('node:fs');
const path = require('node:path');

const PRODUCTION_COLLECTOR_BACKEND = 'https://api.tosprotein.com';
const CONFIG_FILE = 'fjellfisk-release-config.json';

function assertProductionBackendUrl(value) {
  const url = typeof value === 'string' ? value.trim() : '';
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error('FJELLFISK_COLLECTOR_BACKEND_URL must be a valid HTTPS URL.');
  }
  if (parsed.protocol !== 'https:' || !parsed.hostname ||
      parsed.hostname === 'localhost' || parsed.hostname.endsWith('.localhost') ||
      parsed.hostname.includes('emulator')) {
    throw new Error('Refusing a release build without a production HTTPS Collector backend.');
  }
  if (parsed.origin !== PRODUCTION_COLLECTOR_BACKEND || parsed.pathname !== '/' ||
      parsed.search || parsed.hash) {
    throw new Error(`Release builds must use ${PRODUCTION_COLLECTOR_BACKEND}.`);
  }
  return parsed.origin;
}

function writeWebBuildConfig(directory, backendUrl) {
  const configuredBackendUrl = assertProductionBackendUrl(backendUrl);
  const output = path.join(directory, CONFIG_FILE);
  fs.writeFileSync(output, JSON.stringify({
    collectorBackendUrl: configuredBackendUrl,
  }) + '\n');
}

function assertWebBuildConfig(directory) {
  const configPath = path.join(directory, CONFIG_FILE);
  if (!fs.existsSync(configPath)) {
    throw new Error('Missing release build configuration. Use tool/build_release.ps1 for release builds.');
  }
  let config;
  try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch {
    throw new Error('Invalid release build configuration. Rebuild with tool/build_release.ps1.');
  }
  assertProductionBackendUrl(config.collectorBackendUrl);
}

if (require.main === module) {
  assertProductionBackendUrl(process.argv[2] ?? '');
  console.log('Validated Fjellfisk production Collector backend.');
}

module.exports = {
  CONFIG_FILE,
  PRODUCTION_COLLECTOR_BACKEND,
  assertProductionBackendUrl,
  assertWebBuildConfig,
  writeWebBuildConfig,
};
