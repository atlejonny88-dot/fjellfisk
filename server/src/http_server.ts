import {createServer, type IncomingMessage, type Server, type ServerResponse} from 'node:http';

import type {AdminAuthorizer} from './firebase_admin_authorizer.js';
import {asPairingError, PairingError} from './pairing/errors.js';
import type {PairingService} from './pairing/service.js';

const maxJsonBytes = 32 * 1024;

function sendJson(response: ServerResponse, status: number, value: unknown): void {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  });
  response.end(JSON.stringify(value));
}

async function readJson(request: IncomingMessage): Promise<Record<string, unknown>> {
  let size = 0;
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    const data = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += data.length;
    if (size > maxJsonBytes) {
      throw new PairingError('INVALID_ARGUMENT', 400);
    }
    chunks.push(data);
  }
  if (!chunks.length) return {};
  try {
    const value: unknown = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new PairingError('INVALID_ARGUMENT', 400);
    }
    return value as Record<string, unknown>;
  } catch (error) {
    if (error instanceof PairingError) throw error;
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
}

function collectorAuth(request: IncomingMessage): {collectorId: string; deviceCredential: string} {
  return {
    collectorId: request.headers['x-fjellfisk-collector-id'] ?? '',
    deviceCredential: request.headers['x-fjellfisk-device-credential'] ?? '',
  } as {collectorId: string; deviceCredential: string};
}

function sourceFingerprint(request: IncomingMessage): string {
  return request.socket.remoteAddress ?? 'unknown-source';
}

function pathParts(pathname: string): string[] {
  return pathname.split('/').filter(Boolean).map(decodeURIComponent);
}

export interface HttpApiOptions {
  pairingService: PairingService;
  adminAuthorizer: AdminAuthorizer;
  log?: (message: string) => void;
}

export function createHttpApi(options: HttpApiOptions): Server {
  return createServer(async (request, response) => {
    const method = request.method ?? 'GET';
    const url = new URL(request.url ?? '/', 'http://localhost');
    try {
      if (method === 'GET' && url.pathname === '/health') {
        try {
          await options.pairingService.healthcheck();
          sendJson(response, 200, {status: 'ok', database: 'ok'});
        } catch {
          options.log?.('healthcheck_failed database=unavailable');
          sendJson(response, 503, {status: 'degraded', database: 'unavailable'});
        }
        return;
      }

      if (method === 'POST' && url.pathname === '/collector/v1/register') {
        sendJson(response, 201, await options.pairingService.registerCollector(
          await readJson(request), sourceFingerprint(request),
        ));
        return;
      }
      if (method === 'POST' && url.pathname === '/collector/v1/pairing-code') {
        sendJson(response, 200, await options.pairingService.issuePairingCode(collectorAuth(request)));
        return;
      }
      if ((method === 'GET' || method === 'POST') && url.pathname === '/collector/v1/status') {
        if (method === 'POST') await readJson(request);
        sendJson(response, 200, await options.pairingService.getCollectorStatus(collectorAuth(request)));
        return;
      }

      if (method === 'POST' && url.pathname === '/admin/v1/collectors/claim') {
        const body = await readJson(request);
        const siteId = typeof body.siteId === 'string' ? body.siteId : '';
        const actor = await options.adminAuthorizer.authorize(request.headers.authorization, siteId);
        sendJson(response, 200, await options.pairingService.claimCollector({
          actor,
          pairingCode: body.pairingCode,
          siteId: body.siteId,
          sourceFingerprint: `uid:${actor.uid}:${sourceFingerprint(request)}`,
        }));
        return;
      }

      const parts = pathParts(url.pathname);
      if (method === 'GET' && parts.length === 5 && parts[0] === 'admin' && parts[1] === 'v1' && parts[2] === 'sites' && parts[4] === 'collectors') {
        const actor = await options.adminAuthorizer.authorize(request.headers.authorization, parts[3]);
        sendJson(response, 200, await options.pairingService.listCollectorsForSite(actor, parts[3]));
        return;
      }
      if (method === 'POST' && parts.length === 5 && parts[0] === 'admin' && parts[1] === 'v1' && parts[2] === 'collectors' && (parts[4] === 'revoke' || parts[4] === 'reset-for-pairing')) {
        const body = await readJson(request);
        const siteId = typeof body.siteId === 'string' ? body.siteId : '';
        const actor = await options.adminAuthorizer.authorize(request.headers.authorization, siteId);
        const result = parts[4] === 'revoke'
          ? await options.pairingService.revokeCollector(actor, parts[3], body.siteId)
          : await options.pairingService.resetCollectorForPairing(actor, parts[3], body.siteId);
        sendJson(response, 200, result);
        return;
      }

      sendJson(response, 404, {error: {code: 'COLLECTOR_NOT_FOUND'}});
    } catch (error) {
      const pairingError = asPairingError(error);
      if (pairingError.httpStatus >= 500) {
        options.log?.(`request_failed code=${pairingError.code}`);
      }
      sendJson(response, pairingError.httpStatus, {error: {code: pairingError.code}});
    }
  });
}
