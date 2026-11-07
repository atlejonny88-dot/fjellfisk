# Fjellfisk VACON Control v0.4.0

Fjellfisk VACON Control er et separat Windows-program for direkte,
skrivebeskyttet overvåking av VACON 100 FLOW over en allerede etablert VPN.
Programmet er uavhengig av Pelasyn, Fjellfisk-appen og Collector.

## Sikkerhetsgrense

v0.4.0 er **kun overvåking**.

- Programmet oppretter bare Modbus TCP `FC04`-forespørsler (Read Input
  Registers).
- Det kan bare lese den kompilerte prosessdatablokken PDU `2100` til `2110`
  (dokumenterte registre `2101` til `2111`).
- Det finnes ingen Modbus-skrivefunksjon, ingen start/stopp-kommando, ingen
  frekvensskriving og ingen skjult innstilling som kan aktivere dette.
- Det endrer ikke VACON-parameter, VPN, Windows-nettverk, Collector, Vigo,
  P-NET, Pelasyn eller Fjellfisk-data.

Frekvenskontroll og start/stopp vises som en fremtidig arbeidsflate, men alle
tilhørende kontroller er deaktivert. De kan ikke sende en fysisk kommando.

## Faktisk overvåking

Standardprofilen brukes bare når operatøren eksplisitt velger **Koble til**:

- Modell: `VACON 100 FLOW`
- IP: `192.168.30.50`
- Port: `502`
- Unit ID: `255`
- Funksjon: `FC04`
- Oppdateringsintervall: 2 sekunder
- Utdatert data: etter 8 sekunder uten vellykket lesing

Dokumentert output-frekvens er register `2104`, som leses med nullbasert
PDU-adresse `2103` (`0x0837`) og deles på `100` før den vises i Hz.

Motorhastighet (`2105`) og motorstrøm (`2106`) vises som rå prosessdata til
skalering og lokal registermapping er verifisert for den aktuelle omformeren.
De presenteres derfor ikke som verifisert RPM eller ampere. Statusord og aktiv
feilkode vises, men ingen uverifisert feilkodebeskrivelse blir oppfunnet.

Hvis kommunikasjonen feiler, beholdes siste vellykkede måling synlig med en
tydelig status for utdaterte data. Programmet krasjer ikke og gjør ingen
automatisk tilkoblings- eller kontrollhandling uten at operatøren velger
**Koble til**.

## Lokal konfigurasjon

Oppsettet kan holde flere lokale drive-profiler. En profil inneholder:

- ID, visningsnavn og modell
- IPv4-adresse, subnettmaske, gateway og valgfri DNS-metadata
- Modbus-port og Unit ID
- dokumentert frekvensområde

Profilene endrer aldri PC-ens nettverk eller omformerens konfigurasjon. De
lagres uten legitimasjon i:

```text
%LOCALAPPDATA%\Fjellfisk\VaconMonitor\drives.json
```

Valg av en annen drive lagres lokalt og tas i bruk ved en eksplisitt omstart av
monitoren. En ugyldig profil blir avvist uten å overskrive den eksisterende
filen.

## Logg

Kommunikasjonsstatus og trygge telemetriopplysninger logges med rotasjon i:

```text
C:\ProgramData\Fjellfisk\VaconMonitor\logs\vacon-monitor.log
```

Loggen inneholder tidspunkt, trygg drive-ID, feilklasse, faktisk frekvens når
den finnes og rådata for hastighet/strøm. Den inneholder ikke passord, token,
VPN-endepunkt eller Modbus-payload.

## Bygg og test

Kjør fra denne mappen:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-VaconMonitor.ps1
```

Scriptet kjører lokale tester med fiktive transportresponser og publiserer en
selvstendig `win-x86`-fil til:

```text
publish\Fjellfisk.VaconControl.exe
```

Testene kontakter ikke VACON. Reell verifikasjon må gjøres kontrollert av
operatør etter at Beijer CloudVPN er tilkoblet.

## Før fysisk kontroll kan vurderes senere

Ingen fysisk styring er godkjent av denne versjonen. Før en senere, separat
idriftsettelse må ansvarlig elektro- og prosesseier dokumentere:

1. Eksakt modell, firmware og aktuell Modbus-/fieldbus-opsjon.
2. Kontrollord, referanseregister, Modbus-funksjon og skaleringsregler.
3. Feltbuss som aktiv kontrollkilde og korrekt lokal/fjern-velger.
4. Pumpespesifikke minimums-/maksimumsfrekvenser og ramper.
5. Prosessinterlocks, nødstopp, manuell overstyring og feilreset.
6. Atferd ved kommunikasjonsbrudd og restart.

Først etter separat godkjenning kan en ny versjon vurderes. Denne versjonen
skal ikke brukes til å starte, stoppe eller endre frekvens på fysisk utstyr.
