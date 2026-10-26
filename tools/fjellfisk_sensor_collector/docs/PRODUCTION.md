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
  It exposes only `--identity`, `--status`, `--discovery-status`, and the
  foreground-only `--read-once` verification command.
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
reported by dynamic discovery. The buffer/output is a future HTTPS boundary, not an uploader. There is no endpoint,
Firebase, backend credential, or tank mapping in this project.

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

## Release hardening

Production builds are `Release`, `win-x86`, self-contained, with PDB symbols
disabled in the publish output. The production package excludes test sources,
service tools, inventory examples, and internal documentation.

No obfuscator or signing certificate is selected in the repository. The
installer script is an Inno Setup foundation only; it never creates a Windows
Service, Scheduled Task, autostart entry, firewall rule, or reboot action.
