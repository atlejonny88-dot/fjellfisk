import {createHash, createHmac, randomUUID} from 'node:crypto';
import {readFile, mkdir, rename, stat, writeFile} from 'node:fs/promises';
import net from 'node:net';
import path from 'node:path';

const firstPduAddress = 2100;
const registerCount = 11;
const readInputRegisters = 0x04;
const supportedModel = /^vacon\s+100\s+flow$/i;

export class EdgeError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

export function parseEdgeConfig(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new EdgeError('invalid-config');
  const input = value;
  const apiBaseUrl = typeof input.apiBaseUrl === 'string' ? input.apiBaseUrl.trim() : '';
  let uri;
  try {
    uri = new URL(apiBaseUrl);
  } catch {
    uri = null;
  }
  if (!uri || uri.protocol !== 'https:' || !uri.hostname || uri.username || uri.password || uri.pathname !== '/') {
    throw new EdgeError('invalid-api-url');
  }
  const edgeId = requireText(input.edgeId, 128);
  const credentialId = requireText(input.credentialId, 128);
  const credential = requireText(input.credential, 256);
  const pollIntervalSeconds = boundedNumber(input.pollIntervalSeconds ?? 5, 5, 300, true);
  const commandPollSeconds = boundedNumber(input.commandPollSeconds ?? 5, 3, 60, true);
  const readTimeoutMs = boundedNumber(input.readTimeoutMs ?? 3000, 500, 15_000, true);
  return {apiBaseUrl: uri.origin, edgeId, credentialId, credential, pollIntervalSeconds, commandPollSeconds, readTimeoutMs};
}

export async function loadEdgeConfig(configPath) {
  const file = await stat(configPath);
  // The config holds an Edge credential. On Linux it must not be readable by
  // group or other users. Windows ACLs are managed outside this check.
  if (process.platform !== 'win32' && (file.mode & 0o077) !== 0) throw new EdgeError('config-permissions-insecure');
  return parseEdgeConfig(JSON.parse(await readFile(configPath, 'utf8')));
}

export function edgeSignature(credential, timestamp, method, pathname, body, nonce) {
  const digest = createHash('sha256').update(body).digest('hex');
  return createHmac('sha256', credential)
    .update(`${timestamp}\n${method.toUpperCase()}\n${pathname}\n${digest}\n${nonce}`, 'utf8')
    .digest('base64url');
}

export class EdgeApiClient {
  constructor(config, fetchImpl = fetch) {
    this.config = config;
    this.fetch = fetchImpl;
  }

  async get(pathname) {
    return this.#request('GET', pathname, undefined);
  }

  async post(pathname, body) {
    return this.#request('POST', pathname, body);
  }

  async #request(method, pathname, payload) {
    const body = payload === undefined ? Buffer.alloc(0) : Buffer.from(JSON.stringify(payload));
    const timestamp = `${Date.now()}`;
    const nonce = randomUUID();
    const signature = edgeSignature(this.config.credential, timestamp, method, pathname, body, nonce);
    const response = await this.fetch(`${this.config.apiBaseUrl}${pathname}`, {
      method,
      headers: {
        'content-type': 'application/json',
        'x-fjellfisk-edge-id': this.config.edgeId,
        'x-fjellfisk-edge-credential-id': this.config.credentialId,
        'x-fjellfisk-edge-timestamp': timestamp,
        'x-fjellfisk-edge-nonce': nonce,
        'x-fjellfisk-edge-signature': signature,
      },
      body: body.length ? body : undefined,
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw new EdgeError(`api-${response.status}`);
    if (response.status === 204) return null;
    const value = await response.json();
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new EdgeError('api-invalid-response');
    return value;
  }
}

export function buildReadRequest(transactionId, unitId) {
  if (!Number.isInteger(transactionId) || transactionId < 0 || transactionId > 0xffff ||
      !Number.isInteger(unitId) || unitId < 0 || unitId > 0xff) throw new EdgeError('invalid-read');
  const buffer = Buffer.alloc(12);
  buffer.writeUInt16BE(transactionId, 0);
  buffer.writeUInt16BE(0, 2);
  buffer.writeUInt16BE(6, 4);
  buffer.writeUInt8(unitId, 6);
  buffer.writeUInt8(readInputRegisters, 7);
  buffer.writeUInt16BE(firstPduAddress, 8);
  buffer.writeUInt16BE(registerCount, 10);
  return buffer;
}

export function parseReadResponse(response, transactionId, unitId) {
  if (!Buffer.isBuffer(response) || response.length !== 9 + registerCount * 2 ||
      response.readUInt16BE(0) !== transactionId || response.readUInt16BE(2) !== 0 ||
      response.readUInt16BE(4) !== response.length - 6 || response.readUInt8(6) !== unitId ||
      response.readUInt8(7) !== readInputRegisters || response.readUInt8(8) !== registerCount * 2) {
    throw new EdgeError('invalid-read');
  }
  const registers = [];
  for (let index = 0; index < registerCount; index += 1) registers.push(response.readUInt16BE(9 + index * 2));
  return registers;
}

export function decodeVacon100Flow(registers, observedAt = new Date()) {
  if (!Array.isArray(registers) || registers.length !== registerCount) throw new EdgeError('invalid-read');
  const statusWord = registers[0];
  const faultCode = registers[10];
  return {
    measuredAt: observedAt.toISOString(),
    quality: 'LIVE',
    actualFrequencyHz: registers[3] / 100,
    // The facility has not commissioned a separate reference-frequency mapping.
    referenceFrequencyHz: null,
    referenceFrequencyVerified: false,
    // Process data 2105 has been observed, but its RPM mapping remains marked
    // unverified until the installation's process-data profile is confirmed.
    motorSpeedRpm: registers[4],
    motorSpeedVerified: false,
    motorCurrentRaw: registers[5],
    motorCurrentA: null,
    motorCurrentVerified: false,
    ready: (statusWord & 0x0001) !== 0,
    running: (statusWord & 0x0002) !== 0,
    fault: (statusWord & 0x0008) !== 0,
    alarm: (statusWord & 0x0010) !== 0,
    atReference: (statusWord & 0x0020) !== 0,
    activeFaultCode: faultCode === 0 ? null : `${faultCode}`,
  };
}

export class ReadOnlyModbusClient {
  #transactionId = 0;

  async read(device, timeoutMs) {
    validateDevice(device);
    if (!supportedModel.test(device.model)) throw new EdgeError('unsupported-model-profile');
    this.#transactionId = (this.#transactionId + 1) & 0xffff;
    const request = buildReadRequest(this.#transactionId, device.modbusUnitId);
    const response = await exchangeTcp(device.ipAddress, device.modbusTcpPort, request, timeoutMs);
    return decodeVacon100Flow(parseReadResponse(response, this.#transactionId, device.modbusUnitId));
  }
}

export class VaconEdgeRunner {
  constructor({config, api, reader = new ReadOnlyModbusClient(), logger = new EdgeLogger()}) {
    this.config = config;
    this.api = api;
    this.reader = reader;
    this.logger = logger;
    this.devices = new Map();
    this.running = false;
    this.polling = false;
    this.lastConfigAt = 0;
  }

  async refreshConfiguration() {
    const response = await this.api.get('/edge/v1/config');
    if (!Array.isArray(response.devices)) throw new EdgeError('api-invalid-response');
    this.devices = new Map(response.devices.map((device) => [device.deviceId, device]));
    this.lastConfigAt = Date.now();
    this.logger.info(`configuration_updated devices=${this.devices.size}`);
  }

  async runOnce() {
    if (this.polling) return;
    this.polling = true;
    try {
      if (!this.lastConfigAt || Date.now() - this.lastConfigAt >= 60_000) await this.refreshConfiguration();
      // Keep facility traffic deliberately small and deterministic. A failed
      // drive cannot cause overlapping requests to the other configured
      // drives, and this Edge never has more than one Modbus request in flight.
      const readings = [];
      for (const device of this.devices.values()) {
        readings.push(await this.#readDevice(device));
      }
      if (readings.length) await this.api.post('/edge/v1/telemetry', {readings});
      await this.#processCommands();
    } catch (error) {
      this.logger.failure(normalizeError(error));
    } finally {
      this.polling = false;
    }
  }

  async #readDevice(device) {
    try {
      return {deviceId: device.deviceId, ...await this.reader.read(device, this.config.readTimeoutMs)};
    } catch (error) {
      const code = normalizeError(error);
      this.logger.readFailure(device.deviceId, code);
      return failedTelemetry(device.deviceId, code);
    }
  }

  async #processCommands() {
    const response = await this.api.get('/edge/v1/commands');
    if (!Array.isArray(response.commands)) throw new EdgeError('api-invalid-response');
    for (const command of response.commands) {
      if (command.commandType !== 'TEST_CONNECTION' || typeof command.commandId !== 'string') continue;
      const device = this.devices.get(command.deviceId);
      let succeeded = false;
      let resultCode = 'device-not-configured';
      if (device) {
        try {
          const telemetry = {deviceId: device.deviceId, ...await this.reader.read(device, this.config.readTimeoutMs)};
          await this.api.post('/edge/v1/telemetry', {readings: [telemetry]});
          succeeded = true;
          resultCode = 'ok';
        } catch (error) {
          resultCode = normalizeError(error);
        }
      }
      await this.api.post(`/edge/v1/commands/${encodeURIComponent(command.commandId)}/result`, {succeeded, resultCode});
      this.logger.info(`connection_test_completed command=${command.commandId} device=${command.deviceId} result=${resultCode}`);
    }
  }

  async start(signal = new AbortController().signal) {
    if (this.running) throw new EdgeError('already-running');
    this.running = true;
    this.logger.info('edge_started mode=live-read-only');
    try {
      while (!signal.aborted) {
        await this.runOnce();
        await delay(this.config.pollIntervalSeconds * 1000, signal);
      }
    } finally {
      this.running = false;
      this.logger.info('edge_stopped');
    }
  }
}

export class EdgeLogger {
  constructor(logDirectory = process.env.FJELLFISK_VACON_EDGE_LOG_DIR ?? '/var/log/fjellfisk-vacon-edge') {
    this.logDirectory = logDirectory;
    this.path = path.join(logDirectory, 'edge.log');
  }

  async info(message) { await this.#write(`[info] ${message}`); }
  async failure(code) { await this.#write(`[communication_error] category=${safeErrorCode(code)}`); }
  async readFailure(deviceId, code) { await this.#write(`[read_failed] device=${deviceId} category=${safeErrorCode(code)}`); }

  async #write(message) {
    try {
      await mkdir(this.logDirectory, {recursive: true, mode: 0o750});
      try {
        const current = await stat(this.path);
        if (current.size >= 1024 * 1024) {
          await rename(this.path, `${this.path}.1`);
        }
      } catch {}
      await writeFile(this.path, `${new Date().toISOString()} ${message}\n`, {flag: 'a', mode: 0o640});
    } catch {
      // Logging may not turn a read-only monitoring loop into a process crash.
    }
  }
}

function validateDevice(device) {
  if (!device || typeof device !== 'object' || typeof device.deviceId !== 'string' ||
      typeof device.ipAddress !== 'string' || !isIpv4(device.ipAddress) ||
      !Number.isInteger(device.modbusTcpPort) || device.modbusTcpPort < 1 || device.modbusTcpPort > 65535 ||
      !Number.isInteger(device.modbusUnitId) || device.modbusUnitId < 0 || device.modbusUnitId > 255 ||
      typeof device.model !== 'string') throw new EdgeError('invalid-device-configuration');
}

function isIpv4(value) {
  const parts = value.split('.');
  return parts.length === 4 && parts.every((part) => /^\d{1,3}$/.test(part) && Number(part) <= 255);
}

function requireText(value, maximum) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text || text.length > maximum) throw new EdgeError('invalid-config');
  return text;
}

function boundedNumber(value, minimum, maximum, integer) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < minimum || value > maximum || (integer && !Number.isInteger(value))) {
    throw new EdgeError('invalid-config');
  }
  return value;
}

function normalizeError(error) {
  return error instanceof EdgeError ? safeErrorCode(error.code) : 'read-error';
}

function safeErrorCode(value) {
  return ['timeout', 'com-error', 'modbus-error', 'invalid-read', 'read-error', 'unsupported-model-profile', 'device-not-configured']
    .includes(value) ? value : 'read-error';
}

function failedTelemetry(deviceId, code) {
  return {
    deviceId,
    measuredAt: new Date().toISOString(),
    quality: 'FAILED',
    actualFrequencyHz: null,
    referenceFrequencyHz: null,
    referenceFrequencyVerified: false,
    motorSpeedRpm: null,
    motorSpeedVerified: false,
    motorCurrentRaw: null,
    motorCurrentA: null,
    motorCurrentVerified: false,
    ready: null,
    running: null,
    fault: null,
    alarm: null,
    atReference: null,
    activeFaultCode: null,
    errorCategory: safeErrorCode(code),
  };
}

async function exchangeTcp(host, port, request, timeoutMs) {
  return new Promise((resolve, reject) => {
    const socket = new net.Socket();
    const chunks = [];
    let expectedLength = null;
    let settled = false;
    const complete = (error, result) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      error ? reject(error) : resolve(result);
    };
    socket.setTimeout(timeoutMs);
    socket.once('timeout', () => complete(new EdgeError('timeout')));
    socket.once('error', () => complete(new EdgeError('modbus-error')));
    socket.on('data', (chunk) => {
      chunks.push(chunk);
      const response = Buffer.concat(chunks);
      if (response.length >= 6 && expectedLength === null) expectedLength = response.readUInt16BE(4) + 6;
      if (expectedLength !== null && response.length === expectedLength) complete(null, response);
      else if (expectedLength !== null && response.length > expectedLength) complete(new EdgeError('invalid-read'));
    });
    socket.connect(port, host, () => socket.write(request));
  });
}

function delay(milliseconds, signal) {
  if (signal.aborted) return Promise.resolve();
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, milliseconds);
    signal.addEventListener('abort', () => { clearTimeout(timer); resolve(); }, {once: true});
  });
}
