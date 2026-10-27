export const MAX_PAIRING_CODE_LIFETIME_SECONDS = 600;

export const COLLECTOR_STATES = ['UNPAIRED', 'PAIRED', 'REVOKED'] as const;
export type CollectorState = (typeof COLLECTOR_STATES)[number];

export const PAIRING_CODE_STATES = [
  'ACTIVE',
  'USED',
  'SUPERSEDED',
  'EXPIRED',
] as const;
export type PairingCodeState = (typeof PAIRING_CODE_STATES)[number];

export const AUDIT_EVENTS = {
  collectorPaired: 'COLLECTOR_PAIRED',
  collectorRegistered: 'COLLECTOR_REGISTERED',
  collectorResetForPairing: 'COLLECTOR_RESET_FOR_PAIRING',
  collectorRevoked: 'COLLECTOR_REVOKED',
  pairingCodeClaimed: 'PAIRING_CODE_CLAIMED',
  pairingCodeIssued: 'PAIRING_CODE_ISSUED',
  pairingCodeSuperseded: 'PAIRING_CODE_SUPERSEDED',
} as const;

export const DEFAULT_RATE_LIMITS = {
  claim: {limit: 12, windowSeconds: 600},
  claimSource: {limit: 30, windowSeconds: 600},
  pairingCode: {limit: 8, windowSeconds: 600},
  registration: {limit: 5, windowSeconds: 600},
} as const;

export type RateLimitScope = keyof typeof DEFAULT_RATE_LIMITS;
export type RateLimits = typeof DEFAULT_RATE_LIMITS;
