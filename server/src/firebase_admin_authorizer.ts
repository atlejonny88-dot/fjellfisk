import {applicationDefault, getApp, getApps, initializeApp, type App} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';

import {PairingError} from './pairing/errors.js';
import type {AuthorizedAdmin} from './pairing/types.js';

export interface AdminAuthorizer {
  authorize(authorizationHeader: string | undefined, siteId: string): Promise<AuthorizedAdmin>;
}

/**
 * Server-only Firebase identity bridge. The Collector never receives an Admin
 * credential; this verifier uses Application Default Credentials mounted only
 * on the server when the backend is deployed.
 */
export class FirebaseAdminAuthorizer implements AdminAuthorizer {
  private readonly app: App;

  constructor(projectId: string) {
    this.app = getApps()[0] ?? initializeApp({credential: applicationDefault(), projectId});
  }

  async authorize(authorizationHeader: string | undefined, siteId: string): Promise<AuthorizedAdmin> {
    const token = authorizationHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    let uid: string;
    try {
      uid = (await getAuth(this.app).verifyIdToken(token)).uid;
    } catch {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    const [user, site] = await Promise.all([
      getFirestore(this.app).collection('users').doc(uid).get(),
      getFirestore(this.app).collection('facilities').doc(siteId).get(),
    ]);
    if (!site.exists) {
      throw new PairingError('SITE_NOT_FOUND', 404);
    }
    const userData = user.data();
    if (!user.exists || userData?.disabled === true || userData?.role !== 'admin') {
      throw new PairingError('FORBIDDEN', 403);
    }
    const siteData = site.data();
    const organizationId = typeof siteData?.organizationId === 'string'
      ? siteData.organizationId
      : null;
    return {uid, organizationId, allowedSiteIds: [siteId]};
  }
}

export class StaticAdminAuthorizer implements AdminAuthorizer {
  constructor(private readonly actor: AuthorizedAdmin) {}

  async authorize(authorizationHeader: string | undefined, siteId: string): Promise<AuthorizedAdmin> {
    if (authorizationHeader !== 'Bearer local-test-admin') {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    if (!this.actor.allowedSiteIds.includes(siteId)) {
      throw new PairingError('FORBIDDEN', 403);
    }
    return this.actor;
  }
}
