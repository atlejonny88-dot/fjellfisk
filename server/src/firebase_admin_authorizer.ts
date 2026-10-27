import {applicationDefault, getApps, initializeApp, type App} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';

import {PairingError} from './pairing/errors.js';
import type {AuthorizedAdmin} from './pairing/types.js';

export interface AdminAuthorizer {
  authorize(authorizationHeader: string | undefined, siteId: string): Promise<AuthorizedAdmin>;
}

export interface FirebaseAuthorizationDocument {
  exists: boolean;
  data(): Record<string, unknown> | undefined;
}

export interface FirebaseAuthorizationDataSource {
  verifyIdToken(token: string): Promise<{uid: string}>;
  getUser(uid: string): Promise<FirebaseAuthorizationDocument>;
  getFacility(siteId: string): Promise<FirebaseAuthorizationDocument>;
}

function createDataSource(app: App): FirebaseAuthorizationDataSource {
  const auth = getAuth(app);
  const firestore = getFirestore(app);
  return {
    verifyIdToken: (token) => auth.verifyIdToken(token),
    getUser: (uid) => firestore.collection('users').doc(uid).get(),
    getFacility: (siteId) => firestore.collection('facilities').doc(siteId).get(),
  };
}

/**
 * Server-only Firebase identity bridge. The Collector never receives an Admin
 * credential; this verifier uses Application Default Credentials mounted only
 * on the server when the backend is deployed. The data source intentionally
 * exposes only Firebase token verification and two document reads.
 */
export class FirebaseAdminAuthorizer implements AdminAuthorizer {
  private readonly dataSource: FirebaseAuthorizationDataSource;

  constructor(projectId: string, dataSource?: FirebaseAuthorizationDataSource) {
    if (dataSource) {
      this.dataSource = dataSource;
      return;
    }

    const appName = `fjellfisk-${projectId}`;
    const app = getApps().find((candidate) => candidate.name === appName) ??
      initializeApp({credential: applicationDefault(), projectId}, appName);
    this.dataSource = createDataSource(app);
  }

  async authorize(authorizationHeader: string | undefined, siteId: string): Promise<AuthorizedAdmin> {
    const token = authorizationHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    let uid: string;
    try {
      // Firebase Admin validates the token signature, project audience and
      // issuer before returning the UID.
      uid = (await this.dataSource.verifyIdToken(token)).uid;
    } catch {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    const [user, site] = await Promise.all([
      this.dataSource.getUser(uid),
      this.dataSource.getFacility(siteId),
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
