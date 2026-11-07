import {PairingError} from '../pairing/errors.js';
import type {VaconDeviceConfiguration} from './types.js';

function stringField(input: Record<string, unknown>, key: string, maximum: number): string {
  const value = typeof input[key] === 'string' ? input[key].trim() : '';
  if (!value || value.length > maximum) throw new PairingError('INVALID_ARGUMENT', 400);
  return value;
}

function integerField(input: Record<string, unknown>, key: string, minimum: number, maximum: number): number {
  const value = input[key];
  if (typeof value !== 'number' || !Number.isInteger(value) || value < minimum || value > maximum) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  return value;
}

function frequencyField(input: Record<string, unknown>, key: string): number {
  const value = input[key];
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 400) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  return value;
}

function isIpv4(value: string): boolean {
  const parts = value.split('.');
  return parts.length === 4 && parts.every((part) => /^\d{1,3}$/.test(part) && Number(part) <= 255);
}

function ipv4Field(input: Record<string, unknown>, key: string): string {
  const value = stringField(input, key, 45);
  if (!isIpv4(value)) throw new PairingError('INVALID_ARGUMENT', 400);
  return value;
}

function dnsField(input: Record<string, unknown>): string {
  const value = stringField(input, 'dns', 255);
  // DNS may be an IPv4 address or an installation-controlled hostname. It is
  // documentation only; the backend does not resolve or apply it.
  if (!/^[A-Za-z0-9.-]+$/.test(value)) throw new PairingError('INVALID_ARGUMENT', 400);
  return value;
}

export function validateVaconDeviceConfiguration(input: unknown): VaconDeviceConfiguration {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  const value = input as Record<string, unknown>;
  const minFrequencyHz = frequencyField(value, 'minFrequencyHz');
  const maxFrequencyHz = frequencyField(value, 'maxFrequencyHz');
  if (maxFrequencyHz <= minFrequencyHz) throw new PairingError('INVALID_ARGUMENT', 400);
  if (typeof value.monitoringEnabled !== 'boolean') throw new PairingError('INVALID_ARGUMENT', 400);
  return {
    displayName: stringField(value, 'displayName', 120),
    manufacturer: stringField(value, 'manufacturer', 120),
    model: stringField(value, 'model', 120),
    ipAddress: ipv4Field(value, 'ipAddress'),
    subnetMask: ipv4Field(value, 'subnetMask'),
    gateway: ipv4Field(value, 'gateway'),
    dns: dnsField(value),
    modbusTcpPort: integerField(value, 'modbusTcpPort', 1, 65535),
    modbusUnitId: integerField(value, 'modbusUnitId', 0, 255),
    minFrequencyHz,
    maxFrequencyHz,
    edgeServerId: stringField(value, 'edgeServerId', 120),
    monitoringEnabled: value.monitoringEnabled,
  };
}

export function requireVaconDeviceId(value: unknown): string {
  const id = typeof value === 'string' ? value.trim() : '';
  if (!/^[a-zA-Z0-9-]{1,128}$/.test(id)) throw new PairingError('INVALID_ARGUMENT', 400);
  return id;
}
