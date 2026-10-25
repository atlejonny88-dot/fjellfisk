# Fjellfisk Collector pairing-backend

Denne dokumentasjonen beskriver backend-grunnlaget for sikker pairing av en
installert Fjellfisk Collector. Ingen del av denne løsningen leser Vigo/P-NET,
starter Collector som tjeneste eller laster opp sensordata.

## Eksisterende modell som gjenbrukes

Fjellfisk bruker Firebase Authentication og `users/{uid}` med globale roller
`admin`, `ansatt` og `leser`. Anlegg finnes allerede som
`facilities/{facilityId}`. Pairing bruker derfor `facilityId` som `siteId`.
Hvis et facility-dokument senere får `organizationId`, brukes det; ellers er
`organizationId` lik `siteId`. Det finnes foreløpig ikke en autoritativ
per-site-entitlement-modell. Et isolert hook i Functions kan utvides når den
finnes, uten å endre Collector-modellen.

## API-overflate

Firebase Hosting videresender `/collector/v1/**` til `collectorApi` i
`europe-west1` når denne konfigurasjonen senere deployes.

| Endepunkt | Autentisering | Formål |
| --- | --- | --- |
| `POST /collector/v1/register` | Ingen, begrenset per kilde | Oppretter en `UNPAIRED` Collector og returnerer en engangs device credential. |
| `POST /collector/v1/pairing-code` | `x-fjellfisk-collector-id` og `x-fjellfisk-device-credential` | Returnerer ny pairing-kode for en uparet Collector. |
| `GET` eller `POST /collector/v1/status` | Samme Collector-headere | Returnerer bare Collectorens egen minimale state. |

Collector-credential sendes kun i HTTPS-headerne. Den må aldri ligge i URL,
logg eller konfigurasjonsfil. Production Collector lagrer den med Windows
DPAPI og dekrypterer den bare mens en autorisert backend-request bygges.

App-siden er Firebase callable Functions, ikke direkte Firestore-tilgang:

- `claimCollector({ pairingCode, siteId })`
- `listCollectorsForSite({ siteId })`
- `revokeCollector({ collectorId, siteId })`
- `resetCollectorForPairing({ collectorId, siteId })`

Alle krever en innlogget, aktiv bruker med dagens `admin`-rolle. Dette omgår
ikke Flutter-reglene og gir ikke leser/ansatt skrivetilgang.

## Data og hemmeligheter

Serveren oppretter et tilfeldig UUID som `collectorId` og en tilfeldig
256-bit `deviceCredential`. Klartekst-credential returneres bare én gang fra
register-endepunktet. Firestore lagrer kun en HMAC-SHA256-digest med
domene-separasjon.

Pairing-koder har format `FJ-XXXX-XXXX-XXXX`, unngår forvekslingsbare tegn og
lagres også bare som HMAC-SHA256-digest. Koden og credentialet kan derfor ikke
leses ut av Firestore eller returverdiene fra app-callables.

Funksjonene krever Firebase Secret `COLLECTOR_PAIRING_PEPPER` ved fremtidig
produksjonsdeploy. Den er ikke opprettet av denne endringen og skal aldri
legges i repoet. `functions/.secret.local.example` viser kun lokalt format.

Faktiske server-only collections:

```
collectorDevices/{collectorId}
collectorPairingCodes/{hmacDigest}
collectorAuditEvents/{eventId}
collectorRateLimits/{hmacDigest}
```

`collectorDevices` inneholder state, credential-digest, metadata, tidspunkter
og eventuell site-binding. `collectorPairingCodes` inneholder ikke klartekst,
bare collectorId, state og tidsstempler. Audit inneholder eventType,
collectorId, site/org, actorUid og tidspunkt, aldri hemmeligheter.

Firestore-reglene nekter direkte lesing og skriving av alle fire collectionene.
Bare Admin SDK i Functions kan håndtere dem.

## State og pairing-livssyklus

Collector state er én av `UNPAIRED`, `PAIRED` eller `REVOKED`. Koder er
`ACTIVE`, `USED`, `SUPERSEDED` eller `EXPIRED`.

En utstedt kode varer maksimalt 600 sekunder, basert på serverklokke.
Når Collector ber om ny kode, blir foregående aktive kode markert
`SUPERSEDED`. Ved claim utføres alle kontroller og disse oppdateringene i én
Firestore-transaksjon:

1. Bekreft aktiv admin og eksisterende site.
2. Verifiser HMAC-lookup, state og utløpstid.
3. Bekreft at Collector fremdeles er `UNPAIRED`.
4. Bind Collector til organization/site, marker kode `USED` og supersed andre
   aktive koder.
5. Skriv `PAIRING_CODE_CLAIMED` og `COLLECTOR_PAIRED` audit-events.

En Firestore-transaksjon retries ved konflikt, slik at to parallelle claim-forsøk
gir nøyaktig én vinner. Utløpte koder avvises selv om cleanup ennå ikke er kjørt.

`revokeCollector` sperrer en allerede paret Collector og invaliderer aktive
koder. Collector blir aldri automatisk aktiv igjen. Bare eksplisitt
`resetCollectorForPairing` setter en Collector tilbake til `UNPAIRED`.

## Rate limiting og feil

Rate-limit-tellere oppdateres atomisk i Firestore og har standardvindu på ti
minutter: registrering 5/kilde, kodeutstedelse 8/Collector, claim 12/bruker og
30/kilde. Subject lagres kun som HMAC-digest. Feilsvar bruker stabile koder,
blant annet `COLLECTOR_AUTH_FAILED`, `PAIRING_CODE_EXPIRED`,
`PAIRING_CODE_USED`, `PAIRING_RATE_LIMITED`, `SITE_NOT_FOUND` og `FORBIDDEN`.
Ingen stack trace eller interne Firestore-feil sendes til klienten.

## Lokal emulator og tester

Installer Functions-avhengigheter én gang:

```powershell
cd C:\Users\ofs\fjellfisk\functions
npm install
```

Kjør hele backend- og Firestore-regelpakken mot emulator, ikke produksjon.
Start Functions, Firestore og Auth sammen i ett PowerShell-vindu. Functions
arver da bare den lokale Firestore-adressen og den lokale test-pepperen:

```powershell
cd C:\Users\ofs\fjellfisk
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8787'
$env:COLLECTOR_PAIRING_PEPPER = 'local-test-only-secret-not-for-production'
firebase emulators:start --only "functions,firestore,auth" --project trolltungaarctictrout
```

```powershell
# Nytt vindu: Tester
cd C:\Users\ofs\fjellfisk
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8787'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:FJELLFISK_FUNCTIONS_EMULATOR = '1'
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:5001'
$env:GCLOUD_PROJECT = 'trolltungaarctictrout'
npm --prefix functions run test:emulator
npm --prefix functions run test:collector-e2e
npm --prefix tool/rules test
```

`npm --prefix functions test` kjører rene kryptografitester uten emulator og
skipper emulatorintegrasjon når `FIRESTORE_EMULATOR_HOST` mangler.
`test:emulator` krever derimot både Firestore- og Functions-emulatoren og
stopper med feil dersom miljøet ikke er satt. Emulatorpakken dekker registrering, digest uten klartekst, autentisering,
rotasjon, expiry, autorisasjon, atomisk dobbelt-claim, revoke/reset, rate
limit og klientforbud i Firestore-reglene. `test:collector-e2e` er en separat
lokal HTTP-test av register → kode → admin-claim → `PAIRED`; den skriver aldri
kode eller credential til testoutput.

## Release-pausepunkt

### Status

- Pairing-backenden er ferdig validert lokalt.
- Functions Emulator: 15/15 tester bestått.
- Firestore-regler: 11/11 tester bestått.
- Collector: 76/76 tester bestått.
- Production Collector pairing mot emulator er validert, inkludert separat
  pairing-vindu som lukkes ved `PAIRED`.
- Backend-styrt kode-rotasjon med maksimum 10 minutter, register → kode →
  claim → `PAIRED` og DPAPI-identitet er validert lokalt.
- Ingen pairing-Functions, Collector-regler eller Collector-endepunkt er
  deployet. `trolltungaarctictrout` er urørt.
- Vigo/P-NET og produksjonssensorer har ikke vært brukt.
- Lokal `npm audit` rapporterer én høy transitive `body-parser`-advarsel.
  Dependencies er bevisst ikke endret i denne pauseoppgaven; den må vurderes
  kontrollert før en fremtidig release.

`fjellfisk-staging` ble opprettet som et isolert prosjekt før pausen. Det har
en tom Firestore Standard-database i `europe-west1` med slettingsbeskyttelse,
men har ingen Firebase-app, ingen Collector-data, ingen deployede Functions,
ingen secret og ingen billing-tilknytning. Det må ikke endres, slettes eller
brukes videre uten en ny eksplisitt releasebeslutning.

### Neste steg når arbeidet gjenopptas

1. Avklar om eksisterende `fjellfisk-staging` skal beholdes eller erstattes;
   opprett det bare dersom prosjektet ikke lenger finnes.
2. Aktiver nødvendige Google/Firebase-tjenester og kontroller billing/budsjett.
3. Opprett staging-secretet `COLLECTOR_PAIRING_PEPPER` uten å eksponere verdien.
4. Deploy kun pairing-backenden og nødvendige Firestore-regler til staging.
5. Test ekte HTTPS-pairing mot staging.
6. Implementer først deretter 60-sekunders autostart.
7. Bygg en ny installer.

## Production Collector pairing-klient

Customer-facing `Fjellfisk.SensorCollector.exe --pairing` bruker kun den
beskrevne API-kontrakten. Pairing kjører separat fra Vigo/discovery og leser
ingen sensor. Endepunktet velges i denne rekkefølgen:

1. `--pairing-backend-url=https://.../collector/v1`
2. `FJELLFISK_COLLECTOR_PAIRING_URL`
3. `%ProgramData%\Fjellfisk\SensorCollector\config\pairing-backend.json`

Kun HTTPS aksepteres normalt. Lokal HTTP er kun tillatt med både
`--pairing-emulator` og en eksplisitt loopback-adresse. Production Collector
har aldri en localhost-standard.

Backend `collectorId` og et DPAPI-beskyttet device credential lagres i
`%ProgramData%\Fjellfisk\SensorCollector\identity\pairing.json`. Pairing-koden
lagres aldri. Det separate pairing-vinduet får bare kode/status via lokal named
pipe, aldri credential, endpoint eller Vigo-data.

Kjør en full Collector-emulatorkontroll etter at emulatoren over er klar:

```powershell
cd C:\Users\ofs\fjellfisk
$env:FJELLFISK_COLLECTOR_E2E = '1'
$env:FJELLFISK_REPOSITORY_ROOT = 'C:\Users\ofs\fjellfisk'
$env:FJELLFISK_COLLECTOR_PROCESS_E2E = '1'
$env:FJELLFISK_COLLECTOR_PUBLISH_DIRECTORY = 'C:\Users\ofs\fjellfisk\tools\fjellfisk_sensor_collector\src\Fjellfisk.SensorCollector.Production\bin\Release\net6.0-windows\win-x86\publish'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8787'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:5001'
dotnet run --project tools\fjellfisk_sensor_collector\tests\Fjellfisk.SensorCollector.Tests\Fjellfisk.SensorCollector.Tests.csproj
```

## Før produksjonsrelease

1. Opprett `COLLECTOR_PAIRING_PEPPER` som Firebase Secret under kontrollert
   release-prosess.
2. Deploy Functions, de forberedte Firestore-reglene og Hosting-rewrite i en
   godkjent release, aldri fra en Collector-PC.
3. Konfigurer det godkjente HTTPS-endepunktet på kundenes Collector-maskiner;
   ikke bruk emulatorargumentene utenfor lokal test.
4. Utvid `requireAdminForSite` først når Fjellfisk har en autoritativ
   per-site-entitlement-modell.
