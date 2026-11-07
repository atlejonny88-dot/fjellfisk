import {createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, timingSafeEqual} from 'node:crypto';

const encryptionAlgorithm = 'aes-256-gcm';

export function parseEdgeEncryptionKey(value: string | undefined): Buffer | null {
  if (!value?.trim()) return null;
  try {
    const key = Buffer.from(value, 'base64url');
    return key.length === 32 ? key : null;
  } catch {
    return null;
  }
}

export function generateEdgeCredential(): string {
  return randomBytes(32).toString('base64url');
}

export function encryptEdgeCredential(credential: string, key: Buffer): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv(encryptionAlgorithm, key, iv);
  const encrypted = Buffer.concat([cipher.update(credential, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return ['v1', iv.toString('base64url'), tag.toString('base64url'), encrypted.toString('base64url')].join('.');
}

export function decryptEdgeCredential(ciphertext: string, key: Buffer): string | null {
  const [version, ivText, tagText, payloadText] = ciphertext.split('.');
  if (version !== 'v1' || !ivText || !tagText || !payloadText) return null;
  try {
    const decipher = createDecipheriv(encryptionAlgorithm, key, Buffer.from(ivText, 'base64url'));
    decipher.setAuthTag(Buffer.from(tagText, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(payloadText, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    return null;
  }
}

export function edgeBodyDigest(body: Buffer): string {
  return createHash('sha256').update(body).digest('hex');
}

export function edgeRequestSignature(
  credential: string,
  timestamp: string,
  method: string,
  pathname: string,
  bodyDigest: string,
  nonce: string,
): string {
  return createHmac('sha256', credential)
    .update(`${timestamp}\n${method.toUpperCase()}\n${pathname}\n${bodyDigest}\n${nonce}`, 'utf8')
    .digest('base64url');
}

export function safeSignatureEquals(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left, 'utf8');
  const rightBytes = Buffer.from(right, 'utf8');
  return leftBytes.length === rightBytes.length && timingSafeEqual(leftBytes, rightBytes);
}
