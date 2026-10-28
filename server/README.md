# Fjellfisk self-hosted Collector backend

Dette er et separat Node.js/TypeScript- og PostgreSQL-backend for Fjellfisk
Collector-pairing. Den er installert for privat intern test på Pelasyn, men er
ikke koblet til Vigo/P-NET, Firebase, Flutter-appen eller Collectorens
eksisterende DPAPI-identitet.

## Formål og avgrensning

Den eksisterende Firebase-implementasjonen i `functions/` har vært brukt som
referanse. Gjenbrukbar logikk er flyttet hit som vanlig TypeScript:

- kodeformat, kryptografiske HMAC-digests og konstant-tid-sammenligning
- pairing state-maskin, levetid, kode-rotasjon, audit og rate-limit-regler
- Collector HTTP-kontrakten: register, pairing-kode og status

Følgende er bevisst Firebase-spesifikt og holdes utenfor pairing-kjernen:

- Firebase Functions `onRequest`/`onCall`-adapters
- Firestore-dokumenter og Firestore-transaksjoner
- Firebase Secret Manager-binding gjennom Functions
- Firebase Auth-kontekst fra callable functions

Den self-hostede serveren har i stedet REST-administrator-endepunkter.
Firebase ID-tokenet brukes bare som identitetsbevis: backend validerer tokenets
RS256-signatur, issuer og audience mot Firebase sine offentlige JWK-nøkler.
Dette bruker verken Firebase Admin SDK, Firestore, Google Cloud IAM eller en
privat service-account credential.

PostgreSQL er autoritativ for Collector-tilgang:

- `collector_users`: Firebase UID og aktiv/deaktivert Collector-konto.
- `collector_facilities`: anlegg/site og status.
- `collector_facility_memberships`: `ADMIN`, `OPERATOR` eller `VIEWER` per
  anlegg.
- `collector_addon_entitlements`: om `collector` er aktivt for anlegget,
  inkludert valgfri utløpstid.

Et gyldig Firebase UID har ingen Collector-rettighet alene. Pairing krever
aktiv PostgreSQL-adminmembership for valgt anlegg og aktivt, ikke-utløpt
Collector-entitlement. Backend leser eller skriver aldri
`users/{uid}` eller `facilities/{facilityId}` i Firestore.

## API

Collector-kontrakten er bevisst kompatibel med eksisterende Collector:

| Endepunkt | Metode | Autentisering |
| --- | --- | --- |
| `/collector/v1/register` | `POST` | ingen, begrenset per kilde |
| `/collector/v1/pairing-code` | `POST` | `x-fjellfisk-collector-id`, `x-fjellfisk-device-credential` |
| `/collector/v1/status` | `GET` / `POST` | samme Collector-headere |
| `/admin/v1/collectors/claim` | `POST` | Firebase ID-token |
| `/admin/v1/sites/:siteId/collectors` | `GET` | Firebase ID-token |
| `/admin/v1/collectors/:collectorId/revoke` | `POST` | Firebase ID-token |
| `/admin/v1/collectors/:collectorId/reset-for-pairing` | `POST` | Firebase ID-token |

Administrator-kall bruker `siteId` i body der det er relevant. Serveren
verifiserer ID-tokenet, finner UID-ens membership i PostgreSQL og kontrollerer
Collector-entitlement før claim. Klienten kan ikke sende `admin=true`, rolle
eller anleggstilknytning som autoritet. Collector får aldri
administratorrettigheter.

## Sikker datamodell

Migreringen `migrations/001_collector_pairing.sql` oppretter:

- `collector_devices`: UUID, state, metadata og **kun HMAC-digest** av
  device-credential.
- `collector_pairing_codes`: HMAC-digest av kode, server-tid, state og claim.
- `collector_audit_events`: minimal hendelseslogg uten hemmeligheter.
- `collector_rate_limits`: HMAC-digestet subject og teller per tidsvindu.

`migrations/002_collector_authority.sql` oppretter PostgreSQL-modellen for
Collector-brukere, anlegg, medlemskap, entitlements og det engangs
bootstrap-registeret. Det finnes ingen permanent Firestore-synkronisering.

Credentialet er tilfeldig 256-bit og returneres kun ved første registrering.
Pairing-koder har format `FJ-XXXX-XXXX-XXXX`, lagres aldri som klartekst, er
engangs, utløper på maksimum 600 sekunder og roteres ved ny kodeutstedelse.
PostgreSQL-transaksjoner er serializable, med radlåser og retry ved
serialiseringskonflikt, slik at to samtidige claim-forsøk får nøyaktig én vinner.

## Lokal utvikling

Kopier aldri reelle secrets inn i `.env.example`. Lokalt trenger testene ingen
database, Firebase service-account eller nettverk:

```powershell
cd C:\Users\ofs\fjellfisk\server
npm install
npm run check
npm test
```

En valgfri PostgreSQL-integrasjonstest kan senere kjøres mot en dedikert lokal
testdatabase gjennom `FJELLFISK_POSTGRES_TEST_URL`; den er ikke nødvendig for
den rene pairing-testpakken og må aldri peke mot produksjonsdata. Testen
trunkerer Collector-tabellene i databasen den får oppgitt, og skal derfor bare
kjøres mot en tom, disponibel testdatabase:

```powershell
$env:FJELLFISK_POSTGRES_TEST_URL = 'postgresql://.../fjellfisk_collector_test'
npm run test:postgres
```

## Pelasyn intern testinstallasjon

Den kontrollerte interninstallasjonen ligger i `/opt/fjellfisk-server` og
kjører bare to Fjellfisk-containere: `fjellfisk-backend` og PostgreSQL. Ingen
eksisterende CasaOS-, Uptime Kuma- eller Netdata-container er en del av dette
Compose-prosjektet eller endret av installasjonen.

- Serverkonfigurasjonen ligger i `/opt/fjellfisk-server/.env` med filmodus
  `600`. Den inneholder lokale, tilfeldig genererte serverhemmeligheter og skal
  aldri kopieres til repo, Collector eller Flutter.
- API-et er bundet eksklusivt til `127.0.0.1:8080`.
- PostgreSQL har ingen host-port og er tilgjengelig kun i Docker-nettverket.
- Begge Fjellfisk-containerne har healthcheck og `restart: unless-stopped`.
- Den aktive PostgreSQL-dataen ligger i det isolerte Docker-volumet
  `fjellfisk-server-postgres-data-v2`. Et eldre, tomt initieringsvolum ble
  bevart urørt da det nye volumet ble opprettet; ingen volume ble slettet.

### Firebase Auth-identitet uten service account

`FIREBASE_PROJECT_ID` i Pelasyns `.env` brukes kun til å kontrollere forventet
audience og issuer for Firebase ID-tokenet. Backend henter Firebase sine
offentlige signeringsnøkler over HTTPS ved behov. Ingen Google service account,
Cloud Datastore Viewer, Firebase Admin-credential eller Firestore-lesing skal
opprettes eller konfigureres på Pelasyn.

Før første Collector-claim må den eksplisitte engangs-bootstrapen opprette
første PostgreSQL-admin og anlegg. Operatøren bruker en kjent Firebase UID og
anleggs-ID, uten at backend slår dem opp i Firestore:

```sh
cd /opt/fjellfisk-server
# COLLECTOR_BOOTSTRAP_SECRET må eksistere lokalt i .env og fjernes etterpå.
docker compose run --rm --no-deps fjellfisk-backend \
  npm run bootstrap:authority -- \
  --firebase-uid '<known-firebase-uid>' \
  --facility-id '<known-facility-id>' \
  --facility-name '<facility-name>' \
  --collector-entitlement INACTIVE
```

Dette er transaksjonelt og kan bare lykkes én gang. Etter bootstrap eier
PostgreSQL normale roller, anleggstilknytninger og Collector-entitlements.
En kontrollert, server-side kommersiell flyt kan senere bruke
`PostgresAuthorityRepository.setCollectorEntitlement` for å aktivere
entitlement for et anlegg. Flutter får aldri en klientstyrt self-service-vei
for dette.

`ADMIN_CORS_ORIGINS` er en eksplisitt kommaseparert origin-liste kun for
`/admin/v1/*`. Tom verdi betyr at nettlesere ikke får kryss-origin-tilgang;
det finnes aldri wildcard. For en lokal Flutter Web-test kan en fast lokal
origin, for eksempel `http://localhost:51099`, legges til midlertidig sammen
med den publiserte Fjellfisk-origin-en. Collector-endepunktene trenger ikke
CORS.

Flutter har en opt-in claim-klient: den brukes kun når appen startes med en
eksplisitt build-definisjon, for eksempel
`--dart-define=FJELLFISK_COLLECTOR_BACKEND_URL=https://<privat-tailnet-url>`.
Uten denne definisjonen fortsetter Add-ons-skjermen å bruke sin eksisterende
lokale mock for UI-testen. Den private Tailscale-adressen er ikke hardkodet i
Flutter- eller Collector-kilde.

En ny server kan installeres med samme kontrollerte fremgangsmåte:

```sh
# På Pelasyn etter eksplisitt godkjenning.
sudo install -d -m 700 /opt/fjellfisk-server
cd /opt/fjellfisk-server
# Legg den gjennomgåtte server/-mappen her med vanlig Git- eller filkopi-prosess.
cp .env.example .env
chmod 600 .env
# Fyll inn unike verdier i .env, uten å vise eller dele filen:
#   openssl rand -base64 48   (pepper og Postgres-passord)
docker compose build
docker compose up -d
docker compose ps
curl --fail http://127.0.0.1:8080/health
```

Compose binder API-et til `127.0.0.1:8080` og eksponerer ikke PostgreSQL på
vertsnettverket. Databasen slettes ikke av normal oppstart eller oppdatering.
Loggene roteres av Docker (`10m`, fem filer).

## Første interne Tailnet-fase

Første tilgangsmodell er **Tailscale Serve**, ikke offentlig ingress. Backend
fortsetter å lytte kun lokalt på Pelasyn (`127.0.0.1:8080`), mens Tailscale
terminerer HTTPS og videresender Tailnet-trafikk til den lokale porten. Dette
gir en privat `https://<node>.<tailnet>.ts.net`-adresse uten router-
portvideresending. PostgreSQL forblir kun på det interne Docker-nettverket og
port 5432 får aldri en host-binding.

Den aktive interne testadressen er
`https://pelasyn.taild05c7.ts.net/`. Serve lytter bare på Tailscale-interfacet
på HTTPS-port 443 og videresender til `127.0.0.1:8080`. Tailscale Funnel er
ikke konfigurert, og direkte tilgang til Pelasyns Tailscale-IP på port 8080 er
lukket.

Ingen IP-adresse eller Tailscale-hostnavn er hardkodet i Collector. Når Serve
er aktivert i tailnet-administrasjonen, hentes URL-en fra `tailscale serve`-
output eller `tailscale serve status --json`, og brukes som konfigurasjon, for
eksempel:

```sh
# Kjør bare på Pelasyn etter separat nettverksgodkjenning.
tailscale status
tailscale serve --bg 8080
tailscale serve status --json
```

Tailscale krever at HTTPS-sertifikater og relevante ACL-er er aktivert i
tailnettet. Verifiser fra en autorisert testmaskin med:

```sh
curl --fail https://<node>.<tailnet>.ts.net/health
```

Deretter kan en intern test-Collector få den konfigurerbare URL-en, uten endring
i kildekode:

```powershell
Fjellfisk.SensorCollector.exe --pairing-backend-url https://<node>.<tailnet>.ts.net/collector/v1
```

Ikke bruk `tailscale funnel`, ikke åpne router-/brannmurporter, og ikke
eksponer CasaOS eller PostgreSQL. Tailscale Serve er bare første interne
test-/driftsfase; eksterne kunder skal senere bruke et separat offentlig
HTTPS-endepunkt, for eksempel `https://api.fjellfisk.no`, med samme
Collector-credential- og device-authentisering. Det offentlige endepunktet
skal implementeres som en senere reverse-proxy/TLS-beslutning, uten at kunder
trenger Tailscale eller kjenner Pelasyn-adresser.

### HTTPS senere

Collector krever vanligvis HTTPS. Velg og vurder én av disse senere:

1. Tailscale Serve med HTTPS for kun autoriserte Tailnet-enheter.
2. Caddy eller Nginx med offentlig DNS og Let's Encrypt, etter særskilt
   sikkerhetsgjennomgang.
3. En nettverksisolert reverse proxy som IT drifter.

Ingen av disse er konfigurert nå.

## Sikker oppdatering og backup

`scripts/update-server.sh` bygger og starter containerne uten `down -v`,
database-sletting eller `docker system prune`. Den innebygde migreringsrunneren
kjører versjonerte SQL-filer én gang før API-et starter.

Kjør backup manuelt eller fra en senere godkjent scheduler:

```sh
cd /opt/fjellfisk-server
./scripts/backup-postgres.sh
```

Skriptet laster alltid installasjonens egen `.env` og kan derfor ikke arve
databasevariabler fra en tidligere terminaløkt. Det lager en custom-format
`pg_dump` i `backups/` og roterer kun backup-filer eldre enn 30 dager etter
vellykket dump. Test restore først mot en tom, midlertidig database, aldri
direkte mot produksjonsvolumet:

```sh
docker compose exec -T postgres createdb -U "$POSTGRES_USER" fjellfisk_restore_test
docker compose exec -T postgres pg_restore -U "$POSTGRES_USER" -d fjellfisk_restore_test --clean --if-exists < backups/FIL.dump
```

## Bevisst ikke inkludert

- Ingen Firebase- eller webdeploy.
- Ingen VIGO.PRO, P-NET eller sensorkall.
- Ingen sensoropplasting eller fysisk styring.
- Ingen autostart, systemd-tjeneste eller installasjon på Pelasyn.
- Ingen åpne porter, routerendringer, CasaOS-endringer eller offentlig DNS.
