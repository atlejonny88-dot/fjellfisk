import {randomUUID} from 'node:crypto';

import {PairingError} from '../pairing/errors.js';
import {encryptEdgeCredential, generateEdgeCredential} from './edge_crypto.js';
import type {VaconEdgeProvisioningRepository} from './edge_repository.js';
import type {VaconEdge, VaconEdgeCredential} from './edge_types.js';

const rotationGraceMs = 60 * 60_000;

function requiredText(value: string, maximum: number): string {
  const text = value.trim();
  if (!text || text.length > maximum) throw new PairingError('INVALID_ARGUMENT', 400);
  return text;
}

export interface VaconEdgeProvisioningBundle {
  edgeId: string;
  credentialId: string;
  credential: string;
}

/** Server-only provisioning. The returned credential belongs in a protected
 * local Edge file, never in a browser, Flutter response, or log. */
export class VaconEdgeProvisioningService {
  constructor(
    private readonly repository: VaconEdgeProvisioningRepository,
    private readonly encryptionKey: Buffer | null,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async provision(facilityIdInput: string, displayNameInput: string): Promise<VaconEdgeProvisioningBundle> {
    const key = this.requireKey();
    const facilityId = requiredText(facilityIdInput, 200);
    const displayName = requiredText(displayNameInput, 120);
    const now = this.now();
    const edge: VaconEdge = {
      edgeId: randomUUID(), facilityId, displayName, enabled: true,
      lastSeenAt: null, createdAt: now, updatedAt: now,
    };
    const bundle = this.credentialBundle(edge.edgeId, key, now);
    return this.repository.transaction(async (transaction) => {
      if (!await transaction.facilityExists(facilityId)) throw new PairingError('SITE_NOT_FOUND', 404);
      await transaction.insertEdge(edge);
      await transaction.insertCredential(bundle.credentialRecord);
      await transaction.appendEdgeAudit({
        facilityId, deviceId: null, actorUid: null,
        eventType: 'VACON_EDGE_PROVISIONED', changedFields: ['displayName'], createdAt: now,
      });
      return bundle.publicBundle;
    });
  }

  async rotate(edgeIdInput: string): Promise<VaconEdgeProvisioningBundle> {
    const key = this.requireKey();
    const edgeId = requiredText(edgeIdInput, 128);
    const now = this.now();
    return this.repository.transaction(async (transaction) => {
      const edge = await transaction.getEdge(edgeId);
      if (!edge || !edge.enabled) throw new PairingError('VACON_EDGE_NOT_CONFIGURED', 404);
      const bundle = this.credentialBundle(edge.edgeId, key, now);
      await transaction.deactivateCredentials(edge.edgeId, new Date(now.getTime() + rotationGraceMs));
      await transaction.insertCredential(bundle.credentialRecord);
      await transaction.appendEdgeAudit({
        facilityId: edge.facilityId, deviceId: null, actorUid: null,
        eventType: 'VACON_EDGE_CREDENTIAL_ROTATED', changedFields: [], createdAt: now,
      });
      return bundle.publicBundle;
    });
  }

  private credentialBundle(edgeId: string, key: Buffer, now: Date): {
    credentialRecord: VaconEdgeCredential;
    publicBundle: VaconEdgeProvisioningBundle;
  } {
    const credential = generateEdgeCredential();
    const credentialId = randomUUID();
    return {
      credentialRecord: {
        credentialId, edgeId, credentialCiphertext: encryptEdgeCredential(credential, key),
        active: true, expiresAt: null, createdAt: now,
      },
      publicBundle: {edgeId, credentialId, credential},
    };
  }

  private requireKey(): Buffer {
    if (!this.encryptionKey) throw new PairingError('VACON_EDGE_NOT_CONFIGURED', 503);
    return this.encryptionKey;
  }
}
