import {randomUUID} from 'node:crypto';
import {
  Firestore,
  Timestamp,
  Transaction,
  type DocumentReference,
  type DocumentData,
} from 'firebase-admin/firestore';

import {
  AUDIT_EVENTS,
  COLLECTIONS,
  DEFAULT_RATE_LIMITS,
  MAX_PAIRING_CODE_LIFETIME_SECONDS,
  type CollectorState,
  type PairingCodeState,
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
import {
  requireNonEmptyString,
  validateCollectorMetadata,
  type CollectorRegistrationInput,
} from './validation.js';

interface CollectorDeviceDocument {
  state: CollectorState;
  credentialDigest: string;
  createdAt: Timestamp;
  lastSeenAt: Timestamp;
  collectorVersion: string | null;
  platform: string | null;
  organizationId: string | null;
  siteId: string | null;
  pairedAt: Timestamp | null;
  pairedByUid: string | null;
  revokedAt: Timestamp | null;
}

interface PairingCodeDocument {
  collectorId: string;
  state: PairingCodeState;
  issuedAt: Timestamp;
  expiresAt: Timestamp;
  usedAt: Timestamp | null;
  claimedByUid: string | null;
}

interface AppUserDocument {
  disabled?: unknown;
  role?: unknown;
}

export interface CollectorAuthentication {
  collectorId: string;
  deviceCredential: string;
}

export interface CollectorStatus {
  collectorId: string;
  state: CollectorState;
  organizationId?: string;
  siteId?: string;
  pairedAt?: string;
}

export interface PairingServiceOptions {
  pepper: string;
  now?: () => Date;
  rateLimits?: RateLimits;
}

interface PreparedRateLimit {
  ref: DocumentReference;
  data: {
    scope: keyof RateLimits;
    windowStartedAt: Timestamp;
    count: number;
    updatedAt: Timestamp;
  };
}

export interface RegistrationResult {
  collectorId: string;
  deviceCredential: string;
  state: 'UNPAIRED';
}

export interface PairingCodeResult extends CollectorStatus {
  code?: string;
  issuedAt?: string;
  expiresAt?: string;
  expiresInSeconds?: number;
}

export interface PublicCollectorSummary {
  collectorId: string;
  state: CollectorState;
  createdAt: string;
  lastSeenAt: string;
  collectorVersion: string | null;
  platform: string | null;
  pairedAt: string | null;
}

function toTimestamp(date: Date): Timestamp {
  return Timestamp.fromDate(date);
}

function toIso(value: Timestamp | null | undefined): string | null {
  return value ? value.toDate().toISOString() : null;
}

function isCollectorState(value: unknown): value is CollectorState {
  return value === 'UNPAIRED' || value === 'PAIRED' || value === 'REVOKED';
}

function isPairingCodeState(value: unknown): value is PairingCodeState {
  return value === 'ACTIVE' || value === 'USED' || value === 'SUPERSEDED' || value === 'EXPIRED';
}

function asCollectorDevice(data: DocumentData | undefined): CollectorDeviceDocument | null {
  if (!data || !isCollectorState(data.state) || typeof data.credentialDigest !== 'string') {
    return null;
  }
  return data as CollectorDeviceDocument;
}

function asPairingCode(data: DocumentData | undefined): PairingCodeDocument | null {
  if (!data || !isPairingCodeState(data.state) || typeof data.collectorId !== 'string') {
    return null;
  }
  return data as PairingCodeDocument;
}

export class PairingService {
  private readonly now: () => Date;
  private readonly rateLimits: RateLimits;

  constructor(
    private readonly db: Firestore,
    private readonly options: PairingServiceOptions,
  ) {
    if (!options.pepper || options.pepper.length < 16) {
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
    const credentialDigest = this.digest('credential', deviceCredential);
    const now = toTimestamp(this.now());

    await this.db.runTransaction(async (transaction) => {
      const registrationLimit = await this.prepareRateLimit(
        transaction,
        'registration',
        sourceFingerprint,
        now,
      );

      transaction.create(this.deviceRef(collectorId), {
        state: 'UNPAIRED',
        credentialDigest,
        createdAt: now,
        lastSeenAt: now,
        collectorVersion: metadata.collectorVersion,
        platform: metadata.platform,
        organizationId: null,
        siteId: null,
        pairedAt: null,
        pairedByUid: null,
        revokedAt: null,
      } satisfies CollectorDeviceDocument);
      this.applyRateLimit(transaction, registrationLimit);
      this.writeAudit(transaction, AUDIT_EVENTS.collectorRegistered, collectorId, now);
    });

    // The plaintext credential is intentionally available only in this return value.
    return {collectorId, deviceCredential, state: 'UNPAIRED'};
  }

  async issuePairingCode(auth: CollectorAuthentication): Promise<PairingCodeResult> {
    const now = toTimestamp(this.now());
    const code = generatePairingCode();
    const normalizedCode = normalizePairingCode(code);
    if (!normalizedCode) {
      throw new PairingError('BACKEND_MISCONFIGURED', 500);
    }
    const codeDigest = this.digest('pairing-code', normalizedCode);
    const expiresAt = Timestamp.fromMillis(
      now.toMillis() + MAX_PAIRING_CODE_LIFETIME_SECONDS * 1000,
    );

    return this.db.runTransaction(async (transaction) => {
      const device = await this.authenticateInTransaction(transaction, auth);
      if (device.state === 'PAIRED') {
        return this.statusFromDevice(auth.collectorId, device);
      }
      if (device.state === 'REVOKED') {
        return {collectorId: auth.collectorId, state: 'REVOKED'};
      }

      const pairingCodeLimit = await this.prepareRateLimit(
        transaction,
        'pairingCode',
        auth.collectorId,
        now,
      );
      const activeCodes = await transaction.get(
        this.db.collection(COLLECTIONS.pairingCodes)
          .where('collectorId', '==', auth.collectorId)
          .where('state', '==', 'ACTIVE'),
      );
      this.applyRateLimit(transaction, pairingCodeLimit);
      for (const activeCode of activeCodes.docs) {
        transaction.update(activeCode.ref, {state: 'SUPERSEDED'});
        this.writeAudit(
          transaction,
          AUDIT_EVENTS.pairingCodeSuperseded,
          auth.collectorId,
          now,
        );
      }

      transaction.create(this.codeRef(codeDigest), {
        collectorId: auth.collectorId,
        state: 'ACTIVE',
        issuedAt: now,
        expiresAt,
        usedAt: null,
        claimedByUid: null,
      } satisfies PairingCodeDocument);
      transaction.update(this.deviceRef(auth.collectorId), {lastSeenAt: now});
      this.writeAudit(
        transaction,
        AUDIT_EVENTS.pairingCodeIssued,
        auth.collectorId,
        now,
      );

      return {
        collectorId: auth.collectorId,
        state: 'UNPAIRED' as const,
        code,
        issuedAt: toIso(now) ?? undefined,
        expiresAt: toIso(expiresAt) ?? undefined,
        expiresInSeconds: MAX_PAIRING_CODE_LIFETIME_SECONDS,
      };
    });
  }

  async getCollectorStatus(auth: CollectorAuthentication): Promise<CollectorStatus> {
    const now = toTimestamp(this.now());
    return this.db.runTransaction(async (transaction) => {
      const device = await this.authenticateInTransaction(transaction, auth);
      transaction.update(this.deviceRef(auth.collectorId), {lastSeenAt: now});
      return this.statusFromDevice(auth.collectorId, device);
    });
  }

  async claimCollector(input: {
    actorUid: string | null | undefined;
    pairingCode: unknown;
    siteId: unknown;
    sourceFingerprint: string;
  }): Promise<CollectorStatus> {
    if (!input.actorUid) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    const siteId = requireNonEmptyString(input.siteId);
    const normalizedCode = normalizePairingCode(input.pairingCode);
    if (!normalizedCode) {
      throw new PairingError('PAIRING_CODE_INVALID', 400);
    }

    const codeDigest = this.digest('pairing-code', normalizedCode);
    const now = toTimestamp(this.now());
    const result = await this.db.runTransaction(async (transaction) => {
      const site = await this.requireAdminForSite(transaction, input.actorUid!, siteId);
      const claimLimit = await this.prepareRateLimit(transaction, 'claim', input.actorUid!, now);
      const claimSourceLimit = await this.prepareRateLimit(
        transaction,
        'claimSource',
        input.sourceFingerprint,
        now,
      );

      const codeSnapshot = await transaction.get(this.codeRef(codeDigest));
      const code = asPairingCode(codeSnapshot.data());
      if (!code) {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        return {error: 'PAIRING_CODE_INVALID' as const};
      }
      if (code.state === 'USED') {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        return {error: 'PAIRING_CODE_USED' as const};
      }
      if (code.state === 'SUPERSEDED') {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        return {error: 'PAIRING_CODE_SUPERSEDED' as const};
      }
      if (code.state === 'EXPIRED' || code.expiresAt.toMillis() <= now.toMillis()) {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        if (code.state === 'ACTIVE') {
          transaction.update(codeSnapshot.ref, {state: 'EXPIRED'});
        }
        return {error: 'PAIRING_CODE_EXPIRED' as const};
      }

      const deviceSnapshot = await transaction.get(this.deviceRef(code.collectorId));
      const device = asCollectorDevice(deviceSnapshot.data());
      if (!device) {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        return {error: 'PAIRING_CODE_INVALID' as const};
      }
      if (device.state === 'PAIRED') {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        return {error: 'COLLECTOR_ALREADY_PAIRED' as const};
      }
      if (device.state === 'REVOKED') {
        this.applyRateLimit(transaction, claimLimit);
        this.applyRateLimit(transaction, claimSourceLimit);
        return {error: 'COLLECTOR_REVOKED' as const};
      }

      const activeCodes = await transaction.get(
        this.db.collection(COLLECTIONS.pairingCodes)
          .where('collectorId', '==', code.collectorId)
          .where('state', '==', 'ACTIVE'),
      );
      this.applyRateLimit(transaction, claimLimit);
      this.applyRateLimit(transaction, claimSourceLimit);
      for (const activeCode of activeCodes.docs) {
        if (activeCode.id !== codeDigest) {
          transaction.update(activeCode.ref, {state: 'SUPERSEDED'});
          this.writeAudit(
            transaction,
            AUDIT_EVENTS.pairingCodeSuperseded,
            code.collectorId,
            now,
          );
        }
      }

      const organizationId = this.organizationIdForSite(siteId, site);
      transaction.update(deviceSnapshot.ref, {
        state: 'PAIRED',
        organizationId,
        siteId,
        pairedAt: now,
        pairedByUid: input.actorUid,
        revokedAt: null,
        lastSeenAt: now,
      });
      transaction.update(codeSnapshot.ref, {
        state: 'USED',
        usedAt: now,
        claimedByUid: input.actorUid,
      });
      this.writeAudit(
        transaction,
        AUDIT_EVENTS.pairingCodeClaimed,
        code.collectorId,
        now,
        {organizationId, siteId, actorUid: input.actorUid},
      );
      this.writeAudit(
        transaction,
        AUDIT_EVENTS.collectorPaired,
        code.collectorId,
        now,
        {organizationId, siteId, actorUid: input.actorUid},
      );
      return {
        status: {
          collectorId: code.collectorId,
          state: 'PAIRED' as const,
          organizationId,
          siteId,
          pairedAt: toIso(now) ?? undefined,
        },
      };
    });

    if ('error' in result && typeof result.error === 'string') {
      const status = result.error === 'COLLECTOR_ALREADY_PAIRED' || result.error === 'COLLECTOR_REVOKED'
        ? 409
        : 400;
      throw new PairingError(result.error, status);
    }
    return result.status!;
  }

  async listCollectorsForSite(actorUid: string | null | undefined, siteIdInput: unknown): Promise<PublicCollectorSummary[]> {
    if (!actorUid) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    const siteId = requireNonEmptyString(siteIdInput);
    await this.db.runTransaction((transaction) => this.requireAdminForSite(transaction, actorUid, siteId));
    const snapshot = await this.db.collection(COLLECTIONS.devices)
      .where('siteId', '==', siteId)
      .orderBy('createdAt', 'desc')
      .get();

    return snapshot.docs.flatMap((document) => {
      const device = asCollectorDevice(document.data());
      if (!device) {
        return [];
      }
      return [{
        collectorId: document.id,
        state: device.state,
        createdAt: toIso(device.createdAt) ?? '',
        lastSeenAt: toIso(device.lastSeenAt) ?? '',
        collectorVersion: device.collectorVersion,
        platform: device.platform,
        pairedAt: toIso(device.pairedAt),
      }];
    });
  }

  async revokeCollector(input: {
    actorUid: string | null | undefined;
    collectorId: unknown;
    siteId: unknown;
  }): Promise<void> {
    if (!input.actorUid) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    const collectorId = requireNonEmptyString(input.collectorId);
    const siteId = requireNonEmptyString(input.siteId);
    const now = toTimestamp(this.now());

    await this.db.runTransaction(async (transaction) => {
      await this.requireAdminForSite(transaction, input.actorUid!, siteId);
      const deviceSnapshot = await transaction.get(this.deviceRef(collectorId));
      const device = asCollectorDevice(deviceSnapshot.data());
      if (!device) {
        throw new PairingError('COLLECTOR_NOT_FOUND', 404);
      }
      if (device.siteId !== siteId) {
        throw new PairingError('FORBIDDEN', 403);
      }
      const activeCodes = await transaction.get(
        this.db.collection(COLLECTIONS.pairingCodes)
          .where('collectorId', '==', collectorId)
          .where('state', '==', 'ACTIVE'),
      );
      for (const code of activeCodes.docs) {
        transaction.update(code.ref, {state: 'SUPERSEDED'});
      }
      transaction.update(deviceSnapshot.ref, {state: 'REVOKED', revokedAt: now});
      this.writeAudit(transaction, AUDIT_EVENTS.collectorRevoked, collectorId, now, {
        organizationId: device.organizationId,
        siteId,
        actorUid: input.actorUid!,
      });
    });
  }

  async resetForPairing(input: {
    actorUid: string | null | undefined;
    collectorId: unknown;
    siteId: unknown;
  }): Promise<void> {
    if (!input.actorUid) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    const collectorId = requireNonEmptyString(input.collectorId);
    const siteId = requireNonEmptyString(input.siteId);
    const now = toTimestamp(this.now());

    await this.db.runTransaction(async (transaction) => {
      await this.requireAdminForSite(transaction, input.actorUid!, siteId);
      const deviceSnapshot = await transaction.get(this.deviceRef(collectorId));
      const device = asCollectorDevice(deviceSnapshot.data());
      if (!device) {
        throw new PairingError('COLLECTOR_NOT_FOUND', 404);
      }
      if (device.siteId !== siteId) {
        throw new PairingError('FORBIDDEN', 403);
      }

      const activeCodes = await transaction.get(
        this.db.collection(COLLECTIONS.pairingCodes)
          .where('collectorId', '==', collectorId)
          .where('state', '==', 'ACTIVE'),
      );
      for (const code of activeCodes.docs) {
        transaction.update(code.ref, {state: 'SUPERSEDED'});
      }
      transaction.update(deviceSnapshot.ref, {
        state: 'UNPAIRED',
        organizationId: null,
        siteId: null,
        pairedAt: null,
        pairedByUid: null,
        revokedAt: null,
      });
      this.writeAudit(transaction, AUDIT_EVENTS.collectorResetForPairing, collectorId, now, {
        actorUid: input.actorUid!,
      });
    });
  }

  private async authenticateInTransaction(
    transaction: Transaction,
    auth: CollectorAuthentication,
  ): Promise<CollectorDeviceDocument> {
    const collectorId = requireNonEmptyString(auth.collectorId);
    if (typeof auth.deviceCredential !== 'string' || auth.deviceCredential.length < 32) {
      throw new PairingError('COLLECTOR_AUTH_FAILED', 401);
    }
    const snapshot = await transaction.get(this.deviceRef(collectorId));
    const device = asCollectorDevice(snapshot.data());
    if (!device) {
      throw new PairingError('COLLECTOR_NOT_FOUND', 404);
    }
    const expectedDigest = this.digest('credential', auth.deviceCredential);
    if (!constantTimeEquals(device.credentialDigest, expectedDigest)) {
      throw new PairingError('COLLECTOR_AUTH_FAILED', 401);
    }
    return device;
  }

  private async requireAdminForSite(
    transaction: Transaction,
    actorUid: string,
    siteId: string,
  ): Promise<DocumentData> {
    const [userSnapshot, siteSnapshot] = await Promise.all([
      transaction.get(this.db.collection(COLLECTIONS.users).doc(actorUid)),
      transaction.get(this.db.collection(COLLECTIONS.facilities).doc(siteId)),
    ]);
    const user = userSnapshot.data() as AppUserDocument | undefined;
    if (!user || user.disabled === true || user.role !== 'admin') {
      throw new PairingError('FORBIDDEN', 403);
    }
    if (!siteSnapshot.exists) {
      throw new PairingError('SITE_NOT_FOUND', 404);
    }
    // Existing Fjellfisk roles are global. A future per-site entitlement check
    // belongs here without changing the Collector data model.
    return siteSnapshot.data() ?? {};
  }

  private async prepareRateLimit(
    transaction: Transaction,
    scope: keyof RateLimits,
    subject: string,
    now: Timestamp,
  ): Promise<PreparedRateLimit> {
    const policy = this.rateLimits[scope];
    const rateLimitId = this.digest('rate-limit', `${scope}:${subject}`);
    const ref = this.db.collection(COLLECTIONS.rateLimits).doc(rateLimitId);
    const snapshot = await transaction.get(ref);
    const current = snapshot.data();
    const currentWindow = current?.windowStartedAt instanceof Timestamp
      ? current.windowStartedAt as Timestamp
      : null;
    const expiredWindow = !currentWindow
      || currentWindow.toMillis() + policy.windowSeconds * 1000 <= now.toMillis();
    const count = expiredWindow ? 1 : Number(current?.count ?? 0) + 1;
    if (count > policy.limit) {
      throw new PairingError('PAIRING_RATE_LIMITED', 429);
    }
    return {
      ref,
      data: {
        scope,
        windowStartedAt: expiredWindow ? now : currentWindow!,
        count,
        updatedAt: now,
      },
    };
  }

  private applyRateLimit(transaction: Transaction, update: PreparedRateLimit): void {
    transaction.set(update.ref, update.data, {merge: true});
  }

  private statusFromDevice(collectorId: string, device: CollectorDeviceDocument): CollectorStatus {
    if (device.state !== 'PAIRED') {
      return {collectorId, state: device.state};
    }
    return {
      collectorId,
      state: 'PAIRED',
      organizationId: device.organizationId ?? undefined,
      siteId: device.siteId ?? undefined,
      pairedAt: toIso(device.pairedAt) ?? undefined,
    };
  }

  private organizationIdForSite(siteId: string, site: DocumentData): string {
    return typeof site.organizationId === 'string' && site.organizationId.length > 0
      ? site.organizationId
      : siteId;
  }

  private digest(
    purpose: 'credential' | 'pairing-code' | 'rate-limit',
    value: string,
  ): string {
    return digestWithPepper(this.options.pepper, purpose, value);
  }

  private deviceRef(collectorId: string) {
    return this.db.collection(COLLECTIONS.devices).doc(collectorId);
  }

  private codeRef(codeDigest: string) {
    return this.db.collection(COLLECTIONS.pairingCodes).doc(codeDigest);
  }

  private writeAudit(
    transaction: Transaction,
    eventType: string,
    collectorId: string,
    timestamp: Timestamp,
    context: {
      organizationId?: string | null;
      siteId?: string | null;
      actorUid?: string | null;
    } = {},
  ): void {
    transaction.create(this.db.collection(COLLECTIONS.auditEvents).doc(), {
      eventType,
      collectorId,
      organizationId: context.organizationId ?? null,
      siteId: context.siteId ?? null,
      actorUid: context.actorUid ?? null,
      timestamp,
    });
  }
}
