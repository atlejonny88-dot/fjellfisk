# VACON Control i Fjellfisk V4

Status: **lokal, simulert implementasjon. Ingen fysisk maskinstyring er
tilgjengelig eller aktivert.**

## Det som er levert i Issue #21

- `Add-ons` viser **VACON Control** ved siden av eksisterende Fjellfisk
  Collector. Det finnes ingen ny Plugins-meny.
- V4 har typed modeller for lisens/entitlement, anlegg, site/gateway,
  modellprofil, enhetskonfigurasjon, telemetri og kommandoutfall.
- Ett anlegg kan eie flere sites og flere enheter. Alle ID-er og kommandoer er
  alltid facility-scopede.
- Den lokale testprofilen viser faktisk frekvens, referanse, drift/stopp,
  strøm, effekt, status, alarmkode, tidspunkt og datakvalitet.
- Bare administrator kan sende en **tydelig merket simulert** kommando. Den
  oppdaterer kun en in-memory testdouble og returnerer separat readback.
- Firestore-reglene blokkerer all klient-SDK-lesing og -skriving av framtidige
  VACON-site-, device-, telemetry-, command-, audit- og entitlement-poster.
  En senere backend må kontrollere medlemskap, lisens, eksplisitt
  `pump.control`, commissioning og kommandoens livssyklus.

## Sikkerhetsinvarianter

Den lokale simulatoren avviser før tilstand kan endres dersom én av disse er
usann:

1. Operatøren har eksplisitt kontrollevne for samme anlegg.
2. VACON Control-entitlement er aktivt for anlegget.
3. Enheten finnes i det samme anlegget.
4. Kommando-ID-en ikke er brukt tidligere.
5. Enheten er uttrykkelig `simulationOnly`.
6. Modellprofilen er dokumentert og har erklært kontrollstøtte.
7. Gatewaystatus er online, lokal interlock er god og telemetrien er fersk.
8. Frekvensen er innenfor den godkjente, per-enhet angitte grensen.

Det finnes ingen nettverks-, TCP-, Modbus-, VPN-, credential- eller
produksjonsuploader-kode i `SimulatedVaconGateway`. Offentlige simulator-API-er
har heller ingen `Write`, `Modbus` eller `Tcp`-metoder.

## Data- og kontrollmodell for senere backend

En fremtidig, separat backend kan bruke denne strukturen under hvert anlegg:

```text
facilities/{facilityId}/
  pluginEntitlements/vacon_control
  vaconSites/{siteId}
  vaconDevices/{deviceId}
  vaconTelemetry/{deviceId}
  vaconCommands/{commandId}
  vaconAudit/{eventId}
```

Direkte Flutter-tilgang er med hensikt blokkert. En kontrollert gateway må
kreve kortlivede backend-autorisasjoner, ha en hardkodet og dokumentert
modellprofil, serialisere per-enhet-kommandoer, aldri gjenkjøre start/stopp ved
nettutfall og oppdatere status først etter verifisert fysisk readback.

## Absolutte releaseblokker før fysisk styring

- Identifiser eksakt VACON-modell, firmware, option-kort og offisiell
  registerdokumentasjon per enhet.
- Etabler en alltid-på, VPN-isolert og minst-privilegert gateway. Ikke eksponer
  Modbus TCP offentlig.
- Implementer backend-autorisering med medlemskap per anlegg og eksplisitt
  `pump.control`, uten å gi vanlig ansattrolle fjernstyring automatisk.
- Bygg gatewayadapter med bare dokumenterte register-/bit-/skaleringsregler.
  Ukjent modell er alltid read-only og ikke idriftsatt.
- Utfør stedlig test med ansvarlig elektro-/automasjonstekniker: lokale
  interlocks, nødstopp, lokal overstyring, VPN-brudd, readback, replay,
  alarmkvittering, timeout og rollback.
- Gjennomgå og deploy backend/rules separat. Denne Issue-grenen deployes ikke.

## Testomfang

Automatiserte lokale tester dekker blant annet fler-anleggsisolasjon, lisens,
rolle, stale telemetri, gatewaybrudd, lokale sperrer, ukjent modell,
frekvensgrenser, replay og at simulatoren ikke eksponerer fysisk transport.
Firestore-regeltesten bekrefter at selv admin-klienter ikke kan lese eller
skrive de planlagte VACON-collectionene direkte.
