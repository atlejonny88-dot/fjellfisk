# Production Collector architecture

## Boundary

**Collector discovers sensors. Fjellfisk owns sensor-to-tank mapping.**

The collector never stores or emits a tank ID, section ID, tank name, section
name, or customer-specific mapping. Its stable sensor IDs are based only on a
validated local Vigo object path.

## Dynamic local discovery

Production discovery observes controlled local Vigo data directories, including
the known `C:\Users\Public\VIGO\DynamicData\Commander5`, `visualvigo`, and
`StaticData` roots when present. It extracts complete supported object paths
from project/runtime content, then validates them with family-specific parsers.

Pacific discovers any configured `Pacific_N / Probe_N` pair. DOM discovers any
configured `DO_Meter_N / DO_N` pair. Counts are not limits: one installation
can have no supported sensors while another can represent thousands.

No COM enumeration, path guessing, numeric probing, or arbitrary user-supplied
PhysId reaches VIGO.PRO. Adapters generate the three fixed scalar leaves only
after a supported local object has been discovered:

- Pacific: `Temperature.Value`, `Ppm.Value`, `Saturation.Value`
- DOM: lowercase `temperature`, `ppm`, `saturation`

`Measurement.AlarmStat` is unsupported and is not read.

Discovery produces a runtime read-only allowlist. The serial STA reader accepts
only an exact descriptor from that allowlist. Discovery and polling are separate
operations; a future scheduler can use controlled rescans, but never rescans on
every polling cycle.

For the controlled `--read-once` verification command, discovery is refreshed
from local Vigo configuration immediately before the single read. The cached
discovery JSON is retained as a local observation record, not trusted as a
manual source of COM paths.

## Production and Service Tool

- `Fjellfisk.SensorCollector.Production` is the customer-facing executable.
  It exposes `--identity`, `--status`, `--discovery-status`, the
  foreground-only `--read-once` verification, `--pairing`, and `--run`.
  Only `--run` combines pairing with ongoing, allowlisted read-only collection.
- `Fjellfisk.Collector.ServiceTool` retains local diagnostics and fixed,
  installation-specific inventories for trained support personnel.

The production project does not compile the Service Tool program, inventory,
diagnostic, soak-test, mockup, or service-host sources.

## Normalized data and buffering

`ProductionCollectorRuntime` reads a discovery-generated allowlist serially
through the one STA COM reader. Every logical sensor yields a
source-independent `CollectorReading` with nullable `temperatureC`,
`oxygenMgL`, and `oxygenSaturationPct`, a timestamp, and `ok`, `degraded`, or
`failed` health. One measurement failure cannot stop another sensor or source
family.

`CollectorBatch` carries collector/build identity and readings only. Each
reading includes per-measurement `ok`, `vigo-error`, `invalid-read`,
`timeout`, `com-error`, or `read-error` status without a PhysId. Its local
batch also retains the generic `sourceType`, `sourceDevice`, and `sourceChannel`
reported by dynamic discovery. The single-round runtime remains transport-free.
`ProductionTelemetrySession` uses this same runtime after confirmed pairing and
sends normalized readings through `HttpsProductionTelemetryUploader`. The
backend identity comes from the existing DPAPI pairing store. No Firebase SDK,
service account, tank mapping, or externally supplied COM path is introduced.

`--read-once` serially reads every sensor found by that invocation's dynamic
discovery, writes exactly one pretty-printed batch JSON file under
`buffer\production-read-YYYY-MM-DD_HHmmss.json`, prints aggregate counts, and
then exits. It has no polling loop, retry loop, service host, autostart, or
network upload. A failed scalar marks only that logical sensor degraded or
failed; the remainder of the dynamically discovered batch still runs.

## Persistent state

Production state lives under:

```text
C:\ProgramData\Fjellfisk\SensorCollector\
  config\
  identity\
  logs\
  buffer\
```

The identity remains a random collector ID plus a DPAPI LocalMachine-protected
secret. A legacy root `identity.json` is migrated into `identity\` on first
production startup, preserving the device identity over upgrade.

## Backend pairing

`--pairing` is a foreground-only production command that registers this
Collector with the approved pairing backend, requests a backend-issued
pairing code and polls the Collector's own state. It does not start Vigo,
discover sensors, upload readings, install anything or change autostart.

The backend URL is configured by command line, environment or local config in
that order:

1. `--pairing-backend-url=https://.../collector/v1`
2. `FJELLFISK_COLLECTOR_PAIRING_URL`
3. `config\pairing-backend.json` with an `endpoint` property

HTTPS is mandatory in normal operation. Loopback HTTP is accepted only when
both `--pairing-emulator` and an explicit loopback URL are supplied for local
test. No production default points to localhost.

The backend `collectorId` and DPAPI-protected device credential are retained
in `identity\pairing.json`; the credential is never printed, logged, put in a
URL or sent to the pairing UI. Pairing codes stay in memory only. The small
Norwegian pairing window runs as a separate `pairing-ui` process and receives
only code, expiry and safe connection-state messages over a named pipe. This
keeps its Windows message loop separate from the Collector's Vigo/COM runtime.

The pairing state machine is independent of sensor health: `Starting`,
`BackendUnavailable`, `Registering`, `Unpaired`, `PairingCodeActive`,
`PairingCodeExpired`, `Paired`, `Revoked` and `AuthenticationFailed`.
Unpaired codes rotate from backend authority at expiry; closing the window
does not stop pairing and a fresh code opens one window again. `PAIRED` closes
the window, while `REVOKED` remains blocked until the backend explicitly
resets it to `UNPAIRED`.

## Operational continuity and safe recovery

The interactive login Scheduled Task starts the production Collector with
`--run` 60 seconds after the Windows user signs in. A local run lock permits
only one Collector process. This is intentional: the Collector must run in
the interactive Windows session that has access to the VIGO.PRO COM server.

Transient backend failures do not clear the DPAPI-protected identity, pairing
credential, Collector ID, pairing state or sensor mappings. The pairing state
machine retries its existing backend flow and does not open a new pairing
window for an already paired Collector solely because the network is
temporarily unavailable.

Read-only sensor failures are recorded locally in the rotating
`logs\\sensor-read.log` file. Entries contain a safe failure classification
(`timeout`, `com-error`, `vigo-error`, `invalid-read` or `read-error`), sensor
family and reader state, but never credentials, pairing codes, complete PhysIds
or measurement values. The active log is bounded to 2 MiB and retains two
rotated archives.

A timed-out STA COM call marks the current reader as blocked. The Collector
does not create parallel COM readers, repeatedly create STA threads, restart
Vigo, restart P-NET, or automatically restart itself. This prevents a second
COM call from racing with a call that may still be executing. If
`sensor-read.log` confirms a blocked reader, a trained operator may assess a
controlled restart of the Collector process only after confirming that process
has exited; this does not re-pair, alter DPAPI identity or change mappings.
It is not an automatic recovery mechanism.

## Release hardening

Production builds are `Release`, `win-x86`, self-contained, with PDB symbols
disabled in the publish output. The production package excludes test sources,
service tools, inventory examples, and internal documentation.

No obfuscator or signing certificate is selected in the repository. The
installer creates the existing interactive login Scheduled Task with a
60-second delay and `--run`. It never creates a Windows Service, Run registry
entry, firewall rule, reboot action, or VIGO/P-NET configuration change.
It does not launch sensor collection at the end of installation.
