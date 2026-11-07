import {PairingError} from './errors.js';

export interface CollectorRegistrationInput {
  collectorVersion?: unknown;
  platform?: unknown;
}

export interface ValidCollectorMetadata {
  collectorVersion: string | null;
  platform: string | null;
}

function optionalShortText(value: unknown): string | null {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  if (typeof value !== 'string' || value.length > 120) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  return value.trim() || null;
}

export function validateCollectorMetadata(
  input: CollectorRegistrationInput,
): ValidCollectorMetadata {
  return {
    collectorVersion: optionalShortText(input.collectorVersion),
    platform: optionalShortText(input.platform),
  };
}

export function requireNonEmptyString(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > 160) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  return value.trim();
}
