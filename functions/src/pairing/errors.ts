export type PairingErrorCode =
  | 'BACKEND_MISCONFIGURED'
  | 'COLLECTOR_ALREADY_PAIRED'
  | 'COLLECTOR_AUTH_FAILED'
  | 'COLLECTOR_NOT_FOUND'
  | 'COLLECTOR_REVOKED'
  | 'FORBIDDEN'
  | 'INVALID_ARGUMENT'
  | 'PAIRING_CODE_EXPIRED'
  | 'PAIRING_CODE_INVALID'
  | 'PAIRING_CODE_SUPERSEDED'
  | 'PAIRING_CODE_USED'
  | 'PAIRING_RATE_LIMITED'
  | 'SITE_NOT_FOUND'
  | 'UNAUTHENTICATED';

export class PairingError extends Error {
  constructor(
    readonly code: PairingErrorCode,
    readonly httpStatus: number,
  ) {
    super(code);
    this.name = 'PairingError';
  }
}

export function asPairingError(error: unknown): PairingError {
  if (error instanceof PairingError) {
    return error;
  }

  return new PairingError('BACKEND_MISCONFIGURED', 500);
}
