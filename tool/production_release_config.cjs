const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const defaultConfigPath = path.join(__dirname, 'production_release_config.json');

function validateCollectorBackendUrl(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error('Production Collector backend URL is required.');
  }

  let url;
  try {
    url = new URL(value.trim());
  } catch (_) {
    throw new Error('Production Collector backend URL must be a valid URL.');
  }

  const host = url.hostname.toLowerCase();
  if (url.protocol !== 'https:') {
    throw new Error('Production Collector backend URL must use HTTPS.');
  }
  if (
    host === 'localhost' ||
    host.endsWith('.localhost') ||
    host === '127.0.0.1' ||
    host === '::1' ||
    host.includes('emulator')
  ) {
    throw new Error('Production Collector backend URL cannot target localhost or an emulator.');
  }
  if (url.username || url.password) {
    throw new Error('Production Collector backend URL cannot contain credentials.');
  }

  return url.origin;
}

function readProductionReleaseConfig(configPath = defaultConfigPath) {
  let raw;
  try {
    raw = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch (error) {
    throw new Error(
      `Unable to read production release configuration: ${error.message}`,
    );
  }

  if (raw?.firebaseProjectId !== 'trolltungaarctictrout') {
    throw new Error('Production Firebase project must be trolltungaarctictrout.');
  }

  return {
    firebaseProjectId: raw.firebaseProjectId,
    collectorBackendUrl: validateCollectorBackendUrl(raw.collectorBackendUrl),
  };
}

function verifyFirebaseProject(projectId, firebaseOptionsPath = path.join(root, 'lib', 'firebase_options.dart')) {
  const source = fs.readFileSync(firebaseOptionsPath, 'utf8');
  const matches = source.match(/projectId:\s*'([^']+)'/g) ?? [];
  if (matches.length === 0 || matches.some((match) => !match.includes(`'${projectId}'`))) {
    throw new Error(`Firebase options must use production project ${projectId}.`);
  }
}

function verifyWebArtifact(buildDirectory, backendUrl) {
  const mainPath = path.join(buildDirectory, 'main.dart.js');
  if (!fs.existsSync(mainPath)) {
    throw new Error('Missing build/web/main.dart.js. Run the production web build first.');
  }

  const main = fs.readFileSync(mainPath, 'utf8');
  if (!main.includes(backendUrl)) {
    throw new Error(
      'Web artifact is missing the production Collector backend URL. Refusing deployment.',
    );
  }
}

function verifyProductionRelease({buildDirectory} = {}) {
  const config = readProductionReleaseConfig();
  verifyFirebaseProject(config.firebaseProjectId);
  if (buildDirectory) verifyWebArtifact(buildDirectory, config.collectorBackendUrl);
  return config;
}

module.exports = {
  defaultConfigPath,
  readProductionReleaseConfig,
  validateCollectorBackendUrl,
  verifyFirebaseProject,
  verifyProductionRelease,
  verifyWebArtifact,
};
