# VACON remote pump integration – implementation and commissioning

Status: **scaffold only / NO physical control enabled**. This feature is
created on a feature branch; it is not deployed. Never expose TCP/502 to the
public internet.

## Goal

Fjellfisk Android + Web -> Firebase Authentication/Firestore -> trusted,
always-on VPN-connected gateway -> Modbus TCP -> VACON frequency converter.

Firebase is the command/status store, not a Modbus bridge. The gateway must
have a VPN route to the drive and must never rely on browser TCP connectivity.

## Already implemented

- Admin-only device registration in Plugins / VACON (IP, port, name).
- Read-only telemetry presentation for all active Fjellfisk users.
- Start/stop, set-frequency and fault-reset command UI for admins.
- All controls disabled until trusted commissioning sets
  `commissioned=true`, `remoteControlEnabled=true`, and reports fresh
  `connection=online` / `measuredAt`.
- Explicit confirmation and fail-closed stale/offline behavior.
- Firestore immutable, short-lived command requests; no client can mark an
  operation as executed. Rules are included but **not deployed**.

**Not yet implemented:** trusted gateway, actual Modbus mapping, VPN routing
for gateway host, commissioning, command processing and readback verification.
Do not enable a live device before these parts are completed and tested.

## Firestore contract

All paths are under `facilities/{facilityId}`.

### `vaconPumps/{pumpId}`

App-created configuration:
`name, ip, port, model, minHz, maxHz, commissioned=false,
remoteControlEnabled=false, createdAt`.

Trusted gateway/commissioning service writes:
`connection` (`online`/`offline`), `measuredAt` (server timestamp of actual
measurement), `running`, `actualHz`, `setpointHz`, `motorCurrentA`,
`motorPowerKw`, `faultCode`.

Gateway/authorized commissioning writes also change `commissioned` and
`remoteControlEnabled` only after field tests. **Do not treat a lack of
fault code or the previous "online" status as proof of safety.**

### `vaconPumpCommands/{commandId}`

App creates once: `pumpId`, `type` one of
`start|stop|setFrequency|faultReset`, `value` (number only for setFrequency,
null otherwise), `status=queued`, `requestedByUid`, `requestedAt` (server
timestamp), `expiresAt` (15 seconds after client request).

Trusted gateway changes status to `processing`, `verified`, `rejected`,
`expired` or `failed` and adds machine-measured results, reason codes and
timestamps. Only **verified readback** may produce `verified`. A queued
document is NEVER proof of actuator execution.

Gateway must atomically claim requests (one execution per command), reject
expired/replayed/out-of-order requests and obey an exclusive per-drive
command lock. On VPN loss, fail safely according to the plant's written
process hazard assessment. Never execute backlog on reconnect.

### `vaconPumpAudit/{eventId}`

Trusted gateway-only writes. Record command id, pump, user, command, old/new
setpoint, timestamp, result, reason and current drive state. Admin-only read.

## Mandatory gateway-side validation

1. Firebase Admin SDK with least privilege, on a controlled gateway host;
   service account key/credentials never committed or embedded in the app.
2. Authenticate request identity against current, non-disabled `users/{uid}`
   and an explicit pump-control role/policy; current scaffold requires admin.
3. Validate request expiry using **gateway/server time**, not the phone clock.
4. Re-read live device status, source mode, local interlocks, range,
   fault state, current reference and drive readiness before every write.
5. Allow only an approved, model-specific register mapping. Never derive
   Modbus addresses or bit masks from client input.
6. Send the write once, then poll the specified status/reference registers
   for readback; distinguish accepted request from verified action.
7. No automatic retries of START/STOP/RESET following a timeout without
   verifying current state. Rate limit and serialize commands.
8. Audit every denied or attempted command and any lost connectivity.
9. Local hardwired stop, E-stop, dry-run, levels, pressure, motor/thermal
   limits, other interlocks always override remote commands.
10. Commission a known loss-of-comms policy including VPN loss, drive
    restart, gateway restart and delayed messages. Decide carefully whether
    pump continues at last valid speed or enters a defined local safe state.

## One-site-visit checklist

### Before travelling
- [ ] Identify VACON exact model, application and firmware version
- [ ] Identify Ethernet port or option card; confirm Modbus TCP support
- [ ] Obtain model/application **register map** including address-offset rules,
      word order, scaling, control word, status word, alarms and reference
- [ ] Identify always-on gateway host and provision VPN access to the plant LAN
- [ ] Verify *from that host* VPN routing/firewall to the designated drive IP
- [ ] Build and bench-test gateway with a simulated Modbus device
- [ ] Configure/publish Firestore security rules only after tests
- [ ] Configure pump as INACTIVE in Fjellfisk; no public IP or secrets in repo
- [ ] Agree in writing on approved Hz range, restart policy and role access

### On-site (responsible electrician/automation technician)
- [ ] Document existing operating state and all local/manual IO/interlocks
- [ ] Export/backup drive parameters and photograph model/option card
- [ ] Record original control place, frequency reference, DI/PLC inputs,
      motor limits, acceleration/deceleration, auto-restart, fault handling
- [ ] Physically connect Ethernet and set IP/netmask/gateway
- [ ] Confirm TCP/502 reachable **via VPN** without public exposure
- [ ] Establish read-only status and verify readings match keypad
- [ ] Agree safe control-place selection, local override and communication
      watchdog settings with responsible automation technician
- [ ] Test START/STOP and allowed frequency step under controlled conditions,
      monitoring pump pressure/flow/levels and drive current
- [ ] Test local manual stop/interlocks remain authoritative
- [ ] Test stale telemetry, bad values, concurrent users, VPN cut, gateway
      outage, power cycle/recovery and prevention of delayed command replay
- [ ] Verify confirmed result and audit trail in Android and Web
- [ ] Restore original settings immediately if any test fails
- [ ] Only after successful sign-off enable `commissioned` and
      `remoteControlEnabled` through trusted commissioning process

### After the visit
- [ ] Keep an editable backup of original and final parameters, firmware
      versions, site diagram, authorised Hz limits and recovery procedure
- [ ] Monitor live telemetry/alerts and review command audit regularly

## Unknowns blocking real control

We still need VACON model and option board, correct control/register map,
an available always-on VPN-connected gateway host, plant interlock diagram,
operator's approved speed limits and loss-of-comms behavior. Those items
must not be guessed.

## Development workflow

Protected flow: branch from `develop`, PR to `develop`, review before merge,
then release to `main` only after proper acceptance testing.
Run `dart format .`, `flutter analyze`, `flutter test`, and emulator tests.
The code and rules in this branch have not been run in this session.
