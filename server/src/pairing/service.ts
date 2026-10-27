import {randomUUID} from 'node:crypto';

import {
  AUDIT_EVENTS,
  DEFAULT_RATE_LIMITS,
  MAX_PAIRING_CODE_LIFETIME_SECONDS,
  type RateLimitScope,
  type RateLimits,
} from './constants.js';
import {
  constantTimeEquals,
  digestWithPepper,
  generateDeviceCredential,
  generatePairingCode,
  normalizePairingCode,
} from './crypto.js';
import {PairingError} from './errors.js';
import type {PairingRepository, PairingTransaction} from './repository.js';
import type {
  AuthorizedAdmin,
  CollectorAuthentication,
  CollectorDevice,
  CollectorStatus,
  PairingCodeResult,
  PublicCollectorSummary,
  RegistrationResult,
} from './types.js';
import {
  requireNonEmptyString,
  validateCollectorMetadata,
  type CollectorRegistrationInput,
} from './validation.js';

export interface PairingServiceOptions {
  pepper: string;
  now?: () => Date;
  rateLimits?: RateLimits;
}

function toIso(value: Date | null | undefined): string | null {
  return value?.toISOString() ?? null;
}

export class PairingService {
  private readonly now: () => Date;
  private readonly rateLimits: RateLimits;

  constructor(
    private readonly repository: PairingRepository,
    private readonly options: PairingServiceOptions,
  ) {
    if (options.pepper.length < 32) {
      throw new PairingError('BACKEND_MISCONFIGURED', 500);
    }
    this.now = options.now ?? (() => new Date());
    this.rateLimits = options.rateLimits ?? DEFAULT_RATE_LIMITS;
  }

  async registerCollector(
    input: CollectorRegistrationInput,
    sourceFingerprint: string,
  ): Promise<RegistrationResult> {
    const metadata = validateCollectorMetadata(input);
    const collectorId = randomUUID();
    const deviceCredential = generateDeviceCredential();
    const now = this.now();

    await this.repository.transaction(async (transaction) => {
      await this.consumeRateLimit(transaction, 'registration', sourceFingerprint, now);
      await transaction.insertCollector({
        collectorId,
        state: 'UNPAIRED',
        credentialDigest: this.digest('credential', deviceCredential),
        collectorVersion: metadata.collectorVersion,
        platform: metadata.platform,
        organizationId: null,
        siteId: null,
        createdAt: now,
        lastSeenAt: now,
        pairedAt: null,
        pairedByUid: null,
        revokedAt: null,
      });
      await transaction.appendAudit({
        eventType: AUDIT_EVENTS.collectorRegistered,
        collectorId,
        createdAt: now,
      });
    });

    // This is the sole point where the plaintext credential exists server-side.
    return {collectorId, deviceCredential, state: 'UNPAIRED'};
  }

  async issuePairingCode(auth: CollectorAuthentication): Promise<PairingCodeResult> {
    const now = this.now();
    const code = generatePairingCode();
    const normalizedCode = normalizePairingCode(code);
    if (!normalizedCode) {
      throw new PairingError('BACKEND_MISCONFIGURED', 500);
    }
    const expiresAt = new Date(now.getTime() + MAX_PAIRING_CODE_LIFETIME_SECONDS * 1000);

    return this.repository.transaction(async (transaction) => {
      const device = await this.authenticateCollector(transaction, auth);
      if (device.state !== 'UNPAIRED') {
        return this.statusFromDevice(device);
      }
      await this.consumeRateLimit(transaction, 'pairingCode', device.collectorId, now);
      const activeCodes = await transaction.listActiveCodes(device.collectorId);
      for (const activeCode of activeCodes) {
        await transaction.updateCode(activeCode.codeDigest, {state: 'SUPERSEDED'});
        await transaction.appendAudit({
          eventType: AUDIT_EVENTS.pairingCodeSuperseded,
          collectorId: device.collectorId,
          createdAt: now,
        });
      }
      await transaction.insertCode({
        codeDigest: this.digest('pairing-code', normalizedCode),
        collectorId: device.collectorId,
        state: 'ACTIVE',
        issuedAt: now,
        expiresAt,
        usedAt: null,
        claimedByUid: null,
      });
      await transaction.updateCollector(device.collectorId, {lastSeenAt: now});
      await transaction.appendAudit({
        eventType: AUDIT_EVENTS.pairingCodeIssued,
        collectorId: device.collectorId,
        createdAt: now,
      });
      return {
        collectorId: device.collectorId,
        state: 'UNPAIRED',
        code,
        issuedAt: now.toISOString(),
        expiresAt: expiresAt.toISOString(),
        expiresInSeconds: MAX_PAIRING_CODE_LIFETIME_SECONDS,
      };
    });
  }

  async getCollectorStatus(auth: CollectorAuthentication): Promise<CollectorStatus> {
    const now = this.now();
    return this.repository.transaction(async (transaction) => {
      const device = await this.authenticateCollector(transaction, auth);
      await transaction.updateCollector(device.collectorId, {lastSeenAt: now});
      return this.statusFromDevice(device);
    });
  }

  async claimCollector(input: {
    actor: AuthorizedAdmin;
    pairingCode: unknown;
    siteId: unknown;
    sourceFingerprint: string;
  }): Promise<CollectorStatus> {
    const siteId = requireNonEmptyString(input.siteId);
    this.requireSiteAccess(input.actor, siteId);
    const normalizedCode = normalizePairingCode(input.pairingCode);
    if (!normalizedCode) {
      throw new PairingError('PAIRING_CODE_INVALID', 400);
    }
    const now = this.now();
    const codeDigest = this.digest('pairing-code', normalizedCode);

    const result = await this.repository.transaction(async (transaction) => {
      await this.consumeRateLimit(transaction, 'claim', input.actor.uid, now);
      await this.consumeRateLimit(transaction, 'claimSource', input.sourceFingerprint, now);
      const code = await transaction.getCode(codeDigest);
      if (!code) {
        return {error: new PairingError('PAIRING_CODE_INVALID', 400)};
      }
      if (code.state === 'USED') {
        return {error: new PairingError('PAIRING_CODE_USED', 409)};
      }
      if (code.state === 'SUPERSEDED') {
        return {error: new PairingError('PAIRING_CODE_SUPERSEDED', 409)};
      }
      if (code.state === 'EXPIRED' || code.expiresAt <= now) {
        if (code.state === 'ACTIVE') {
          await transaction.updateCode(code.codeDigest, {state: 'EXPIRED'});
        }
        return {error: new PairingError('PAIRING_CODE_EXPIRED', 409)};
      }

      const device = await transaction.getCollector(code.collectorId);
      if (!device) {
        return {error: new PairingError('PAIRING_CODE_INVALID', 400)};
      }
      if (device.state === 'PAIRED') {
        return {error: new PairingError('COLLECTOR_ALREADY_PAIRED', 409)};
      }
      if (device.state === 'REVOKED') {
        return {error: new PairingError('COLLECTOR_REVOKED', 409)};
      }

      for (const activeCode of await transaction.listActiveCodes(device.collectorId)) {
        if (activeCode.codeDigest !== code.codeDigest) {
          await transaction.updateCode(activeCode.codeDigest, {state: 'SUPERSEDED'});
          await transaction.appendAudit({
            eventType: AUDIT_EVENTS.pairingCodeSuperseded,
            collectorId: device.collectorId,
            createdAt: now,
          });
        }
      }
      const organizationId = input.actor.organizationId ?? siteId;
      await transaction.updateCollector(device.collectorId, {
        state: 'PAIRED',
        organizationId,
        siteId,
        pairedAt: now,
        pairedByUid: input.actor.uid,
        revokedAt: null,
        lastSeenAt: now,
      });
      await transaction.updateCode(code.codeDigest, {
        state: 'USED',
        usedAt: now,
        claimedByUid: input.actor.uid,
      });
      for (const eventType of [AUDIT_EVENTS.pairingCodeClaimed, AUDIT_EVENTS.collectorPaired]) {
        await transaction.appendAudit({
          eventType,
          collectorId: device.collectorId,
          organizationId,
          siteId,
          actorUid: input.actor.uid,
          createdAt: now,
        });
      }
      return {status: {
        collectorId: device.collectorId,
        state: 'PAIRED' as const,
        organizationId,
        siteId,
        pairedAt: now.toISOString(),
      }};
    });
    if ('error' in result) throw result.error;
    return result.status;
  }

  async listCollectorsForSite(
    actor: AuthorizedAdmin,
    siteIdInput: unknown,
  ): Promise<PublicCollectorSummary[]> {
    const siteId = requireNonEmptyString(siteIdInput);
    this.requireSiteAccess(actor, siteId);
    return this.repository.transaction(async (transaction) =>
      (await transaction.listCollectorsForSite(siteId)).map((device) => ({
        collectorId: device.collectorId,
        state: device.state,
        createdAt: device.createdAt.toISOString(),
        lastSeenAt: device.lastSeenAt.toISOString(),
        collectorVersion: device.collectorVersion,
        platform: device.platform,
        pairedAt: toIso(device.pairedAt),
      })),
    );
  }

  async revokeCollector(
    actor: AuthorizedAdmin,
    collectorIdInput: unknown,
    siteIdInput: unknown,
  ): Promise<CollectorStatus> {
    return this.changeCollectorState(actor, collectorIdInput, siteIdInput, 'REVOKED');
  }

  async resetCollectorForPairing(
    actor: AuthorizedAdmin,
    collectorIdInput: unknown,
    siteIdInput: unknown,
  ): Promise<CollectorStatus> {
    return this.changeCollectorState(actor, collectorIdInput, siteIdInput, 'UNPAIRED');
  }

  async healthcheck(): Promise<void> {
    await this.repository.healthcheck();
  }

  private async changeCollectorState(
    actor: AuthorizedAdmin,
    collectorIdInput: unknown,
    siteIdInput: unknown,
    state: 'REVOKED' | 'UNPAIRED',
  ): Promise<CollectorStatus> {
    const collectorId = requireNonEmptyString(collectorIdInput);
    const siteId = requireNonEmptyString(siteIdInput);
    this.requireSiteAccess(actor, siteId);
    const now = this.now();
    return this.repository.transaction(async (transaction) => {
      const device = await transaction.getCollector(collectorId);
      if (!device) {
        throw new PairingError('COLLECTOR_NOT_FOUND', 404);
      }
      if (device.siteId !== siteId) {
        throw new PairingError('FORBIDDEN', 403);
      }
      const reset = state === 'UNPAIRED';
      if (state === 'REVOKED') {
        for (const activeCode of await transaction.listActiveCodes(collectorId)) {
          await transaction.updateCode(activeCode.codeDigest, {state: 'SUPERSEDED'});
          await transaction.appendAudit({
            eventType: AUDIT_EVENTS.pairingCodeSuperseded,
            collectorId,
            organizationId: device.organizationId,
            siteId,
            actorUid: actor.uid,
            createdAt: now,
          });
        }
      }
      await transaction.updateCollector(collectorId, {
        state,
        organizationId: reset ? null : device.organizationId,
        siteId: reset ? null : device.siteId,
        pairedAt: reset ? null : device.pairedAt,
        pairedByUid: reset ? null : device.pairedByUid,
        revokedAt: state === 'REVOKED' ? now : null,
      });
      await transaction.appendAudit({
        eventType: reset ? AUDIT_EVENTS.collectorResetForPairing : AUDIT_EVENTS.collectorRevoked,
        collectorId,
        organizationId: device.organizationId,
        siteId,
        actorUid: actor.uid,
        createdAt: now,
      });
      return {
        collectorId,
        state,
        ...(state === 'REVOKED' && device.organizationId ? {organizationId: device.organizationId} : {}),
        ...(state === 'REVOKED' && device.siteId ? {siteId: device.siteId} : {}),
      };
    });
  }

  private async authenticateCollector(
    transaction: PairingTransaction,
    auth: CollectorAuthentication,
  ): Promise<CollectorDevice> {
    const collectorId = requireNonEmptyString(auth.collectorId);
    const device = await transaction.getCollector(collectorId);
    if (!device) {
      throw new PairingError('COLLECTOR_NOT_FOUND', 404);
    }
    if (!constantTimeEquals(device.credentialDigest, this.digest('credential', auth.deviceCredential))) {
      throw new PairingError('COLLECTOR_AUTH_FAILED', 401);
    }
    return device;
  }

  private async consumeRateLimit(
    transaction: PairingTransaction,
    scope: RateLimitScope,
    subject: string,
    now: Date,
  ): Promise<void> {
    const policy = this.rateLimits[scope];
    const subjectDigest = this.digest('rate-limit', subject);
    const existing = await transaction.getRateLimit(scope, subjectDigest);
    const isNewWindow = !existing || now.getTime() - existing.windowStartedAt.getTime() >= policy.windowSeconds * 1000;
    const requestCount = isNewWindow ? 1 : existing.requestCount + 1;
    if (requestCount > policy.limit) {
      throw new PairingError('PAIRING_RATE_LIMITED', 429);
    }
    await transaction.upsertRateLimit({
      scope,
      subjectDigest,
      windowStartedAt: isNewWindow ? now : existing.windowStartedAt,
      requestCount,
      updatedAt: now,
    });
  }

  private statusFromDevice(device: CollectorDevice): CollectorStatus {
    return {
      collectorId: device.collectorId,
      state: device.state,
      ...(device.organizationId ? {organizationId: device.organizationId} : {}),
      ...(device.siteId ? {siteId: device.siteId} : {}),
      ...(device.pairedAt ? {pairedAt: device.pairedAt.toISOString()} : {}),
    };
  }

  private requireSiteAccess(actor: AuthorizedAdmin, siteId: string): void {
    if (!actor.allowedSiteIds.includes(siteId)) {
      throw new PairingError('FORBIDDEN', 403);
    }
  }

  private digest(
    purpose: 'credential' | 'pairing-code' | 'rate-limit',
    value: string,
  ): string {
    return digestWithPepper(this.options.pepper, purpose, value);
  }
}
