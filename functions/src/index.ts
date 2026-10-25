import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall, onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import type {Request, Response} from 'express';

import {PairingError, asPairingError} from './pairing/errors.js';
import {PairingService, type CollectorAuthentication} from './pairing/service.js';

if (getApps().length === 0) {
  initializeApp();
}

const pairingPepper = defineSecret('COLLECTOR_PAIRING_PEPPER');
const region = 'europe-west1';

function pairingService(): PairingService {
  const pepper = pairingPepper.value();
  if (!pepper) {
    throw new PairingError('BACKEND_MISCONFIGURED', 500);
  }
  return new PairingService(getFirestore(), {pepper});
}

function sourceFingerprint(request: Request): string {
  const forwarded = request.header('x-forwarded-for')?.split(',')[0]?.trim();
  return forwarded || request.ip || 'unknown-source';
}

function collectorAuthentication(request: Request): CollectorAuthentication {
  return {
    collectorId: request.header('x-fjellfisk-collector-id') ?? '',
    deviceCredential: request.header('x-fjellfisk-device-credential') ?? '',
  };
}

function routeFor(request: Request): string {
  const path = request.path.replace(/\/+$/, '') || '/';
  if (path.endsWith('/collector/v1/register') || path.endsWith('/register')) {
    return 'register';
  }
  if (path.endsWith('/collector/v1/pairing-code') || path.endsWith('/pairing-code')) {
    return 'pairing-code';
  }
  if (path.endsWith('/collector/v1/status') || path.endsWith('/status')) {
    return 'status';
  }
  return 'unknown';
}

function writeCollectorError(response: Response, error: unknown): void {
  const pairingError = asPairingError(error);
  response.status(pairingError.httpStatus).json({error: {code: pairingError.code}});
}

function toCallableError(error: unknown): HttpsError {
  const pairingError = asPairingError(error);
  const status = pairingError.code === 'UNAUTHENTICATED'
    ? 'unauthenticated'
    : pairingError.code === 'FORBIDDEN'
      ? 'permission-denied'
      : pairingError.code === 'SITE_NOT_FOUND' || pairingError.code === 'COLLECTOR_NOT_FOUND'
        ? 'not-found'
        : pairingError.code === 'PAIRING_RATE_LIMITED'
          ? 'resource-exhausted'
          : pairingError.code === 'BACKEND_MISCONFIGURED'
            ? 'failed-precondition'
            : 'invalid-argument';
  return new HttpsError(status, pairingError.code, {code: pairingError.code});
}

export const collectorApi = onRequest(
  {region, secrets: [pairingPepper]},
  async (request, response) => {
    try {
      const route = routeFor(request);
      const service = pairingService();
      if (route === 'register') {
        if (request.method !== 'POST') {
          response.status(405).json({error: {code: 'INVALID_ARGUMENT'}});
          return;
        }
        const result = await service.registerCollector(
          request.body ?? {},
          sourceFingerprint(request),
        );
        response.status(201).json(result);
        return;
      }

      if (route === 'pairing-code') {
        if (request.method !== 'POST') {
          response.status(405).json({error: {code: 'INVALID_ARGUMENT'}});
          return;
        }
        response.status(200).json(
          await service.issuePairingCode(collectorAuthentication(request)),
        );
        return;
      }

      if (route === 'status') {
        if (request.method !== 'GET' && request.method !== 'POST') {
          response.status(405).json({error: {code: 'INVALID_ARGUMENT'}});
          return;
        }
        response.status(200).json(
          await service.getCollectorStatus(collectorAuthentication(request)),
        );
        return;
      }

      response.status(404).json({error: {code: 'COLLECTOR_NOT_FOUND'}});
    } catch (error) {
      writeCollectorError(response, error);
    }
  },
);

export const claimCollector = onCall(
  {region, secrets: [pairingPepper]},
  async (request) => {
    try {
      return await pairingService().claimCollector({
        actorUid: request.auth?.uid,
        pairingCode: request.data?.pairingCode,
        siteId: request.data?.siteId,
        sourceFingerprint: `uid:${request.auth?.uid ?? 'anonymous'}`,
      });
    } catch (error) {
      throw toCallableError(error);
    }
  },
);

export const listCollectorsForSite = onCall(
  {region, secrets: [pairingPepper]},
  async (request) => {
    try {
      return await pairingService().listCollectorsForSite(
        request.auth?.uid,
        request.data?.siteId,
      );
    } catch (error) {
      throw toCallableError(error);
    }
  },
);

export const revokeCollector = onCall(
  {region, secrets: [pairingPepper]},
  async (request) => {
    try {
      await pairingService().revokeCollector({
        actorUid: request.auth?.uid,
        collectorId: request.data?.collectorId,
        siteId: request.data?.siteId,
      });
      return {ok: true};
    } catch (error) {
      throw toCallableError(error);
    }
  },
);

export const resetCollectorForPairing = onCall(
  {region, secrets: [pairingPepper]},
  async (request) => {
    try {
      await pairingService().resetForPairing({
        actorUid: request.auth?.uid,
        collectorId: request.data?.collectorId,
        siteId: request.data?.siteId,
      });
      return {ok: true};
    } catch (error) {
      throw toCallableError(error);
    }
  },
);
