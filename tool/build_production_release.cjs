const {spawnSync} = require('node:child_process');
const path = require('node:path');

const {
  verifyProductionRelease,
  verifyWebArtifact,
} = require('./production_release_config.cjs');

const target = process.argv[2];
if (!['web', 'appbundle'].includes(target)) {
  throw new Error('Usage: node tool/build_production_release.cjs <web|appbundle>');
}

const config = verifyProductionRelease();
const flutter = process.env.FLUTTER_BIN || 'flutter';
const args = [
  'build',
  target,
  '--release',
  `--dart-define=FJELLFISK_COLLECTOR_BACKEND_URL=${config.collectorBackendUrl}`,
  `--dart-define=FJELLFISK_VACON_CONTROL_ENABLED=${config.vaconControlEnabled}`,
];
const result = spawnSync(flutter, args, {
  cwd: path.resolve(__dirname, '..'),
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

if (target === 'web') {
  verifyWebArtifact(path.resolve(__dirname, '../build/web'), config.collectorBackendUrl);
}

console.log(`PASS production ${target} build configuration`);
