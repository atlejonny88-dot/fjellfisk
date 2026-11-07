import assert from 'node:assert/strict';
import test from 'node:test';

import {decryptEdgeCredential} from '../src/vacon/edge_crypto.js';
import type {
  VaconEdgeProvisioningRepository,
  VaconEdgeProvisioningTransaction,
} from '../src/vacon/edge_repository.js';
import {VaconEdgeProvisioningService} from '../src/vacon/edge_provisioning.js';
import type {VaconEdge, VaconEdgeCredential} from '../src/vacon/edge_types.js';

const now = new Date('2026-11-07T11:00:00Z');
const key = Buffer.alloc(32, 9);

class InMemoryProvisioningRepository implements VaconEdgeProvisioningRepository, VaconEdgeProvisioningTransaction {
  readonly facilities = new Set(['facility-01']);
  readonly edges = new Map<string, VaconEdge>();
  readonly credentials: VaconEdgeCredential[] = [];
  readonly audit: {eventType: string}[] = [];

  async transaction<T>(operation: (transaction: VaconEdgeProvisioningTransaction) => Promise<T>): Promise<T> {
    return operation(this);
  }

  async facilityExists(facilityId: string): Promise<boolean> {
    return this.facilities.has(facilityId);
  }

  async getEdge(edgeId: string): Promise<VaconEdge | null> {
    return this.edges.get(edgeId) ?? null;
  }

  async insertEdge(edge: VaconEdge): Promise<void> {
    this.edges.set(edge.edgeId, edge);
  }

  async insertCredential(credential: VaconEdgeCredential): Promise<void> {
    this.credentials.push(credential);
  }

  async deactivateCredentials(edgeId: string, expiresAt: Date): Promise<void> {
    for (const credential of this.credentials) {
      if (credential.edgeId === edgeId && credential.active &&
          (credential.expiresAt === null || credential.expiresAt > expiresAt)) {
        credential.expiresAt = expiresAt;
      }
    }
  }

  async appendEdgeAudit(event: {eventType: string}): Promise<void> {
    this.audit.push(event);
  }
}

test('provisioning encrypts a unique Edge credential and rotation preserves a bounded overlap', async () => {
  const repository = new InMemoryProvisioningRepository();
  const service = new VaconEdgeProvisioningService(repository, key, () => now);

  const first = await service.provision('facility-01', 'Pelasyn Edge');
  const firstRecord = repository.credentials[0];
  assert.ok(firstRecord);
  assert.notEqual(firstRecord?.credentialCiphertext, first.credential);
  assert.equal(decryptEdgeCredential(firstRecord!.credentialCiphertext, key), first.credential);
  assert.equal(repository.audit[0]?.eventType, 'VACON_EDGE_PROVISIONED');

  const second = await service.rotate(first.edgeId);
  assert.notEqual(second.credential, first.credential);
  assert.equal(repository.credentials.length, 2);
  assert.equal(repository.credentials[0]?.expiresAt?.toISOString(), '2026-11-07T12:00:00.000Z');
  assert.equal(repository.audit.at(-1)?.eventType, 'VACON_EDGE_CREDENTIAL_ROTATED');
});
