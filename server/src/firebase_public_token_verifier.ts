import {createRemoteJWKSet, jwtVerify, type JWTPayload} from 'jose';

export interface FirebaseIdentity {
  uid: string;
}

export interface FirebaseIdTokenVerifier {
  verifyIdToken(token: string): Promise<FirebaseIdentity>;
}

export type JwtTokenVerifier = (
  token: string,
  projectId: string,
) => Promise<JWTPayload>;

function firebaseUid(payload: JWTPayload): string {
  const subject = payload.sub;
  if (typeof subject !== 'string' || subject.length === 0 || subject.length > 128) {
    throw new Error('Firebase token has no valid subject');
  }
  const userId = payload.user_id;
  if (userId !== undefined && userId !== subject) {
    throw new Error('Firebase token subject mismatch');
  }
  return subject;
}

const firebasePublicKeySet = createRemoteJWKSet(new URL(
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
));

async function verifyWithGooglePublicKeys(token: string, projectId: string): Promise<JWTPayload> {
  const result = await jwtVerify(token, firebasePublicKeySet, {
    algorithms: ['RS256'],
    audience: projectId,
    issuer: `https://securetoken.google.com/${projectId}`,
  });
  return result.payload;
}

/**
 * Verifies Firebase ID tokens with Firebase's public signing keys. No Google
 * service-account credential, Firebase Admin SDK or Firestore access is used.
 */
export class FirebasePublicTokenVerifier implements FirebaseIdTokenVerifier {
  constructor(
    private readonly projectId: string,
    private readonly verifyJwt: JwtTokenVerifier = verifyWithGooglePublicKeys,
  ) {}

  async verifyIdToken(token: string): Promise<FirebaseIdentity> {
    return {uid: firebaseUid(await this.verifyJwt(token, this.projectId))};
  }
}
