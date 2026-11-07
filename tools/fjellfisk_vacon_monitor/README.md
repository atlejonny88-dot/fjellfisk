# Fjellfisk VACON Control v0.4.0

Fjellfisk VACON Control is a separate Windows desktop program for observing a
VACON 100 FLOW through an already established VPN connection. It is deliberately
not part of the Fjellfisk Flutter application, the Collector, or the Pelasyn
backend.

The live register mapping follows the Danfoss VACON 100 Modbus TCP/UDP and RTU
manual, Appendix 1 and Appendix 2. Process Data OUT fields remain dependent on
the installation's configured mapping.

## Safety boundary

- The simulator has Start, Stop and frequency controls for local test only.
- Live mode has no Modbus write implementation, no transmitted control word,
  and no configuration write path. All real control buttons are disabled.
- It can only construct Modbus TCP function code `04` (Read Input Registers).
- It can only read the contiguous FC04 process-data block from PDU `2100`
  through `2110` (documented registers `2101` through `2111`). This includes
  the status word, output frequency, motor speed, motor current and active
  fault code. The frequency at `2104` is translated to PDU `2103` (`0x0837`)
  and divided by `100` for Hz.
- Process Data OUT mapping is application-configurable. The UI marks motor
  speed and fault-code descriptions as process data until the installation
  mapping is confirmed. Motor current is shown as a raw value only: its
  scaling is not assumed or labelled as amperes.
- The live status word shows documented Ready, Running, Fault, Alarm and At
  Reference bits. An active fault code is displayed, but no fault description
  is invented when the installed fault-code mapping has not been verified.
- It does not start, stop, configure, or otherwise affect VACON, the VPN,
  Collector, Vigo, P-NET, Pelasyn, or Fjellfisk production data.

## v0.4.0 drive setup and command model

The application now separates telemetry reading, command modelling, simulator
execution, safety validation and command-attempt logging.

- The application can hold multiple local VACON connection profiles. Each has a
  display name, IPv4 address, subnet mask, gateway, Modbus TCP port, Unit ID,
  frequency range and a documented-limit marker. These values are local monitor
  metadata only: editing them never changes Windows networking, VPN settings,
  VACON parameters or a physical drive.
- One selected drive is monitored at a time so FC04 polling stays serialized.
  Selecting a different drive is saved locally and requires the operator to
  explicitly restart the monitor before the new profile is used.
- The simulator supports target adjustment in `0.1`, `0.5` and `1.0 Hz`
  steps, Apply, Start and Stop. Apply, Start and Stop each require an explicit
  confirmation in the UI.
- A simulator command is read back and marked acknowledged only when the
  resulting simulated state matches the requested action.
- The documented Fieldbus Control Word (`2001`, PDU `2000`) and Fieldbus Speed
  Reference (`2003`, PDU `2002`) exist only as a simulator command model. No
  TCP request in this source can write either address, and the live TCP
  transport exposes no public write/control API.
- The frequency-reference model converts a configured minimum and maximum
  frequency to the documented `0..10000` normalized reference. It does not
  assume a physical maximum such as `50 Hz`.
- Simulator limits are test-only limits, not approved facility limits. Live
  mode remains read-only and rejects every attempted command before a Modbus
  transport can be used.

The command log contains timestamp, safe drive ID, command, target and actual
frequency when known, mode, result and acknowledgement. It does not contain a
password, token, VPN endpoint or Modbus payload.

## Simulator

The default mode is simulated and does not open a TCP connection:

```powershell
& '.\publish\Fjellfisk.VaconMonitor.exe'
```

The window must show `SIMULERT` and `13,00 Hz`. It supports safe local tests of
target frequency, increment/decrement, Apply, Start, Stop, active fault, and
connection loss. Simulator limits are `0,00–50,00 Hz` and are intentionally not
represented as physical pump limits.

## Controlled live read

Only after the simulation is approved and the Beijer CloudVPN is confirmed
connected, start one of the following from the published folder:

```powershell
& '.\publish\Fjellfisk.VaconMonitor.exe' --live
```

`--live` uses the active local connection profile and keeps the complete
Frequency Control panel disabled. The default profile is:

- Host: `192.168.30.50`
- TCP port: `502`
- Unit ID: `255`
- Function: `04` only
- Poll interval: 2 seconds

The monitor treats data as stale after 8 seconds without a successful read.
It keeps the last value visible but labels it as stale; it never presents stale
data as current.

The profiles are stored without credentials in:

```text
%LOCALAPPDATA%\Fjellfisk\VaconMonitor\drives.json
```

An invalid profile file is rejected without being overwritten. A configured
frequency range constrains the simulator only; it never authorizes physical
control.

## Conditions before any real control work

Real VACON control is deliberately blocked in v0.4.0. Before a later version
can implement any write operation, an operator and the responsible electrical /
process owner must verify and document all of the following:

1. The official VACON 100 FLOW control-word and frequency-reference registers.
2. The required Modbus write function and exact value scaling.
3. The active fieldbus control source, including local/remote switching.
4. Local control, physical emergency stop, pump interlocks and alarm handling.
5. Approved pump-specific minimum/maximum frequency and acceleration limits.
6. Communication-loss behaviour and restart behaviour.

No control register or speculative write function is present in this source.

## Build and test

Use the bundled x86 .NET 6 SDK:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-VaconMonitor.ps1
```

The script runs the local simulated test runner and publishes a self-contained
`win-x86` executable to `publish\Fjellfisk.VaconMonitor.exe`. Communication
failures are logged without endpoint, credentials, or payload values to:

```text
C:\ProgramData\Fjellfisk\VaconMonitor\logs\vacon-monitor.log
```

Control attempts in simulator mode are logged with timestamp, command, target,
acceptance and readback. The log contains no password, token, VPN endpoint, or
Modbus payload.

