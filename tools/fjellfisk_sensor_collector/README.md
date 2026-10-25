# Fjellfisk Sensor Collector development workspace

This workspace contains two deliberately separate executables:

- `Fjellfisk.SensorCollector.Production`: customer-facing, dynamic local
  discovery with no internal diagnostics or service installation behavior.
- `Fjellfisk.Collector.ServiceTool`: internal/support executable retaining the
  fixed, installation-specific diagnostic commands described below.

Read [docs/PRODUCTION.md](docs/PRODUCTION.md) for the production architecture,
runtime allowlist, package layout, and safety boundary. This document's fixed
candidate inventories and diagnostic commands apply to the **Internal Service
Tool**, not the distributed Production Collector.

This is a local Windows `win-x86` collector agent for a future, strictly
one-way Fjellfisk sensor integration:

```
OxyGuard / VIGO.PRO -> Fjellfisk Collector -> future Fjellfisk HTTPS endpoint
```

It is separate from the Flutter application. It has not been installed on an
OxyGuard PC, connected to Firebase, deployed, or used to read a live sensor.

## Safety boundary

- The only production reader is `OxyGuardVigoReader`.
- Its exact `PhysId` values are compiled into `SensorAllowlist`; no path can
  come from Firebase, an endpoint, a file, or command-line input.
- Its internal VIGO.PRO operation surface is limited to the verified `PhysId`
  selector property plus the `Value` and `ErrorCode` read properties.
- It never exposes the COM object, a generic COM invocation method, a write
  operation, a command queue, setpoint support, or cloud-to-VIGO traffic.
- A failed read only produces a local log entry and backoff. It never restarts
  VIGO, P-NET, Windows, a service, or hardware.
- The first real read must be manually approved after the values are compared
  with VisualVIGO. This repository change does not grant that approval.

## Compile-time sensor allowlist

| Key | PhysId | Normalized field |
| --- | --- | --- |
| `pacific01_temperature` | `Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01.Oxygen.Measurement.Temperature.Value` | `temperatureC` |
| `pacific01_oxygen` | `Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01.Oxygen.Measurement.Ppm.Value` | `oxygenMgL` |
| `pacific01_saturation` | `Commander5:Master_Box_1.Pacific.Pacific_01.Probe_01.Oxygen.Measurement.Saturation.Value` | `oxygenSaturationPct` |

The known P-NET value type is `36` / `System.Single`. Temperature is labelled
`°C` in the normalized payload only after the VisualVIGO unit is confirmed
during the approved pilot.

The normal pilot and soak reader continue to use only the three verified
Pacific 01 / Probe 01 values above. `--vigo-inventory` has a separate,
explicit candidate list for Pacific 01 / Probe 01–04 using the same three
scalar suffixes. It is not namespace enumeration and does not probe DOM,
Modbus, arbitrary P-NET paths, or undocumented VIGO members. Probe 02–04
are candidates only until their values have been reviewed on the OxyGuard PC.

### DOM inventory allowlist

`--vigo-dom-inventory` is a separate one-pass diagnostic mode. It has 18
compiled DOM channel candidates: `DO_Meter_0` through `DO_Meter_2`, each with
`DO_0` through `DO_5`. Each channel has only these three scalar paths:

```text
Commander5:Master_Box_1.DOM.DO_Meter_X.DO_Y.Measurement.temperature
Commander5:Master_Box_1.DOM.DO_Meter_X.DO_Y.Measurement.ppm
Commander5:Master_Box_1.DOM.DO_Meter_X.DO_Y.Measurement.saturation
```

These lower-case DOM leaves are deliberately distinct from the Pacific
`Oxygen.Measurement.*.Value` paths. `ppm` maps to `oxygenMgL`, `saturation`
maps to `oxygenSaturationPct`, and `temperature` maps to `temperatureC`.
`Measurement.AlarmStat` is not allowlisted, read, or represented anywhere in
the collector.

## Local identity and enrollment

On first normal startup the agent creates a permanent collector identity in:

```
%ProgramData%\Fjellfisk\SensorCollector
```

`collectorDeviceId` is stored as an identifier. The randomly generated device
secret, pending claim session, and future device credential are stored using
Windows DPAPI `LocalMachine`, never as plaintext. Copying only the published
EXE/files to another PC creates a different identity because the local data
directory is not copied.

The future pairing protocol is represented by `IEnrollmentProvider`:

1. Register a collector identity and HMAC proof at a future
   `POST /collector/register` endpoint.
2. Receive `claimCode`, `expiresAt`, and `claimSession`.
3. Poll pending enrollment every 30 seconds.
4. Persist a connected device credential with DPAPI or stop uploads if the
   enrollment is revoked.

Only `MockEnrollmentProvider` is included today. It makes no network call and
does not contain an organization, site, Firebase Admin key, or service account.

## Commands

All examples below are local. Add `--data-dir=<folder>` when testing so normal
development commands do not create data under `%ProgramData%`.

```powershell
# Display the non-secret identity, enrollment state, and collector version.
Fjellfisk.SensorCollector.exe --identity

# Show current local runtime/status information. This does not read VIGO.PRO.
Fjellfisk.SensorCollector.exe --status

# Demonstrate the local mock pairing code. No network request is made.
Fjellfisk.SensorCollector.exe --enroll

# Run exactly one MockVigoReader cycle.
Fjellfisk.SensorCollector.exe --once

# Show the existing live console mockup.
Fjellfisk.SensorCollector.exe --mockup
```

### First approved VIGO pilot command

Do not run this command until OxyGuard/IT has approved the read-only pilot and
an operator is available to compare all three values with VisualVIGO:

```powershell
.\Fjellfisk.SensorCollector.exe --vigo-pilot
```

It stays in the foreground, reads only the three compiled scalar values
sequentially every 15 seconds, writes only local logs/buffer data, and is
stopped with `Ctrl+C`. It uses a console mock uploader, never a production
backend. A finite diagnostic run can use `--vigo-pilot --cycles=1`, but this is
also not to be used without the same written approval.

### COM diagnostics before the next pilot

The first read-only diagnostic returned `0x80020006` (`DISP_E_UNKNOWNNAME`)
for the initial `SetPhysId` and `GetValue` candidates. The complete, verified
VIGO.PRO read-only binding is now:

| Purpose | Confirmed COM member | Invocation |
| --- | --- | --- |
| Select the fixed scalar path | `PhysId` | property set |
| Read its scalar value | `Value` | property get |
| Read the result code | `ErrorCode` | property get |

On 8 October 2026, the one-shot temperature diagnostic succeeded with a value
of `8.646` and `ErrorCode=0` in 79 ms. The normal reader uses exactly these
three bindings. Preserve the one-shot diagnostic command for future checks on
the **approved OxyGuard PC**:

```powershell
.\Fjellfisk.SensorCollector.exe --vigo-diagnostics
```

It creates VIGO.PRO once, asks only for public IDispatch/ITypeInfo metadata,
then attempts one hardcoded temperature sequence using the `PhysId` selector
property, the `Value` property, and the `ErrorCode` property. It logs a start
and success/failure line for `create_com`, `type_info`, `set_physid_property`,
`value_property`, and `error_code_property`; on the first error it logs the
stage, HRESULT, and message, then exits. It has no polling, retry, upload,
service, or autostart behavior.

Some VIGO.PRO installations return an ITypeInfo count of zero. The collector
does not use `IDispatch::GetIDsOfNames` as a fallback: this specific legacy
COM server caused a CLR marshalling fault during that metadata-only operation.
The diagnostics therefore uses only the fixed temperature path and explicit
`PhysId` selector property, which is a local MIB-address selection rather than
a process-data write.

### Read-only VIGO sensor inventory

`--vigo-inventory` performs exactly one sequential read of the explicit
Pacific 01 / Probe 01–04 candidate list. Each candidate has only these
already-known scalar paths:

- `Oxygen.Measurement.Temperature.Value`
- `Oxygen.Measurement.Ppm.Value` → `oxygenMgL`
- `Oxygen.Measurement.Saturation.Value` → `oxygenSaturationPct`

The command uses the same verified `PhysId` property selector plus `Value` and
`ErrorCode` property reads as the existing reader. It makes no generic COM
calls, performs no discovery/brute force scan, retries no failed path, and has
no uploader, Firebase, service, task, autostart, or configuration behavior.
It must only be run on the approved OxyGuard PC, never on a development PC:

```powershell
.\Fjellfisk.SensorCollector.exe --vigo-inventory
```

The console reports each candidate independently, so an unavailable path does
not stop the next candidate. It writes a local diagnostic-only JSON report to:

```text
%ProgramData%\Fjellfisk\SensorCollector\logs\vigo-inventory-YYYY-MM-DD_HHmm.json
```

### Read-only VIGO DOM inventory

The DOM inventory is also a single sequential pass. It reads exactly 54
numeric values: temperature, ppm, and saturation for each of the 18 compiled
DOM channels. It does not reuse Pacific path shapes, does not read alarms, and
does not start a pilot, soak test, service, uploader, task, or autostart entry.
It must only be run on the approved OxyGuard PC:

```powershell
.\Fjellfisk.SensorCollector.exe --vigo-dom-inventory
```

Its local, diagnostic-only JSON file is written to:

```text
%ProgramData%\Fjellfisk\SensorCollector\logs\vigo-dom-inventory-YYYY-MM-DD_HHmm.json
```

The report contains the stable candidate sensor ID, display name, internal
PhysId metadata, measurement result, ErrorCode, duration, and a failure kind
when applicable. It contains no credentials. PhysIds are diagnostics-only and
must never be shown in the Fjellfisk end-user UI.

### Read-only VIGO soak test

`--vigo-soak-test` is a foreground-only stability test for the already
verified VIGO.PRO reader. It creates no service, Scheduled Task, autostart
entry, Firebase connection, production backend connection, or VIGO/P-NET
configuration change. It uses the same three compile-time allowlisted scalar
paths as the pilot:

- `temperatureC`
- `oxygenMgL` from `Ppm.Value`
- `oxygenSaturationPct` from `Saturation.Value`

The test samples every 15 seconds by default. `--sampling-seconds` can set a
different whole-second interval, but never below 10 seconds. A local-only
acknowledgement is used to exercise the collector's local buffer lifecycle;
it is not an HTTP uploader and it cannot reach Firebase or a production
endpoint.

Run the soak test only from the approved OxyGuard PC, with an operator aware
that it is a read-only observation test. Do not run it from a development PC.
The duration is deliberately restricted to `1h`, `8h`, `24h`, or `72h`:

```powershell
# One-hour confirmation run.
.\Fjellfisk.SensorCollector.exe --vigo-soak-test --duration=1h

# Eight-hour overnight run.
.\Fjellfisk.SensorCollector.exe --vigo-soak-test --duration=8h

# One-day run.
.\Fjellfisk.SensorCollector.exe --vigo-soak-test --duration=24h

# Full 72-hour stability test.
.\Fjellfisk.SensorCollector.exe --vigo-soak-test --duration=72h
```

Use `Ctrl+C` to stop early. The collector exits gracefully and still writes a
summary. Detailed per-cycle entries are written locally to a timestamped file
such as:

```text
%ProgramData%\Fjellfisk\SensorCollector\logs\vigo-soak-2026-10-08_1500.log
```

Logs rotate at 1 MiB with up to three archived files plus the active log. The
final local report is always written to:

```text
%ProgramData%\Fjellfisk\SensorCollector\soak-test-summary.json
```

It contains the requested and actual duration, cycle counts, success rate,
minimum/maximum/average read latency, latest successful reading, longest
failure period, COM errors, timeouts, final buffer count, and controlled exit
reason. The console remains quiet during ordinary cycles and prints a compact
health summary every 15 minutes.

## Service and installer preparation

`CollectorServiceHost` uses the same `CollectorRunner` as interactive mode. It
implements a machine-local mutex, graceful cancellation, retry/backoff, and a
mandatory 60-second startup delay before it can make a reader call. It does
not register a Windows service, create a scheduled task, or create autostart.

If VIGO.PRO later cannot run under a Windows Service account, the same
foreground executable and service host can be launched by a Windows Scheduled
Task. The deployment choice must be tested separately.

The later installer contract is documented in
[`installer/README.md`](installer/README.md). No installer executable exists
yet.

## HTTPS uploader seam

`HttpsMeasurementUploader` accepts only an `https://` endpoint and passes the
stable `measurementId` as its idempotency key. It passes a cancellation timeout
to the eventual transport. `CollectorRunner` already buffers data locally,
resends oldest-first, and backs off at 15, 30, 60, 120, 240, then 300 seconds.

No production HTTP transport, endpoint, Firebase connection, or credential is
configured in this project yet.

## Local build and tests

Both executables target .NET 6 Windows x86 to match the verified 32-bit
VIGO.PRO requirement. From this folder:

```powershell
# Internal Service Tool: diagnostics only, never distribute this publish folder.
& 'C:\Program Files (x86)\dotnet\dotnet.exe' build src\Fjellfisk.SensorCollector\Fjellfisk.SensorCollector.csproj -p:PlatformTarget=x86
& 'C:\Program Files (x86)\dotnet\dotnet.exe' run --project tests\Fjellfisk.SensorCollector.Tests\Fjellfisk.SensorCollector.Tests.csproj -p:PlatformTarget=x86
& 'C:\Program Files (x86)\dotnet\dotnet.exe' publish src\Fjellfisk.SensorCollector\Fjellfisk.SensorCollector.csproj -c Release -r win-x86 --self-contained true -p:PlatformTarget=x86

# Customer Production Collector: no internal diagnostics are compiled in.
& 'C:\Program Files (x86)\dotnet\dotnet.exe' build src\Fjellfisk.SensorCollector.Production\Fjellfisk.SensorCollector.Production.csproj -c Release -p:PlatformTarget=x86
& 'C:\Program Files (x86)\dotnet\dotnet.exe' publish src\Fjellfisk.SensorCollector.Production\Fjellfisk.SensorCollector.Production.csproj -c Release -r win-x86 --self-contained true -p:PlatformTarget=x86
```

## Later file transfer to an OxyGuard PC

After a separately approved production-installation test, copy **all files and
folders** inside this production publish directory, preserving their layout:

```
src\Fjellfisk.SensorCollector.Production\bin\Release\net6.0-windows\win-x86\publish\
```

Do not copy a pre-existing `%ProgramData%\Fjellfisk\SensorCollector` directory
or its identity/enrollment/buffer/log files from another computer. Do not run
an installer, service registration, Scheduled Task, autostart, deploy, or
network configuration change as part of that copy.
