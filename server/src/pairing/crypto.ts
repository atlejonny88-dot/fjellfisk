import {createHmac, randomBytes, randomInt, timingSafeEqual} from 'node:crypto';

const PAIRING_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

export function generateDeviceCredential(): string {
  return randomBytes(32).toString('base64url');
}

export function generatePairingCode(): string {
  const characters = Array.from({length: 12}, () =>
    PAIRING_ALPHABET[randomInt(PAIRING_ALPHABET.length)],
  ).join('');
  return `FJ-${characters.slice(0, 4)}-${characters.slice(4, 8)}-${characters.slice(8)}`;
}

export function normalizePairingCode(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.toUpperCase().replace(/[\s-]/g, '');
  return /^FJ[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{12}$/.test(normalized)
    ? normalized
    : null;
}

export function digestWithPepper(
  pepper: string,
  purpose: 'credential' | 'pairing-code' | 'rate-limit',
  value: string,
): string {
  return createHmac('sha256', pepper)
    .update(`fjellfisk/${purpose}/v1\u0000${value}`, 'utf8')
    .digest('hex');
}

export function constantTimeEquals(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left, 'utf8');
  const rightBytes = Buffer.from(right, 'utf8');
  return leftBytes.length === rightBytes.length && timingSafeEqual(leftBytes, rightBytes);
}
