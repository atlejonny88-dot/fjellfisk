# Fjellfisk: Commercial plugin platform (proposal v0.1)

Date: 2026-10-26
Status: **design contract; not production implementation**.

## Product principle
Base Fjellfisk is one paid product. Optional add-ons have independent subscription
entitlements/pricing; e.g. `vacon_control` and `oxyguard`. Do not couple
individual hardware devices directly to the app release/version. Facility
administrators enable licensed plugins from the same catalogue. Prices,
invoicing providers and license/device limits remain product decisions;
NEVER hardcode monetary prices into the hardware driver.

- No new PIN for VACON: use existing Fjellfisk auth and new facility-scoped
  capability permissions, with auditable remote commands.
- Multiple unrelated customer organizations and facilities, each isolated.
- **Unlimited logical devices in data model**; enforce commercial maximums
  server side only if/when a tier explicitly defines them.
- One facility may have zero, one, or many VACON drives, including DIFFERENT
  model families, firmware and register maps in the same facility.
- One or many physical VPN sites per facility, each with own connector/gateway.
- User-facing configuration: select facility, license VACON Control, add
  gateway/site, add drive, enter name, VPN IP and Modbus port, select model
  profile; do commissioning separately.
- Support independent OxyGuard plugin later without modifying VACON module.

## Proposed Firestore hierarchy (subject to tenant migration)

```text
organizations/{orgId}
  members/{uid}: orgRole
  subscriptions/{pluginId}: plan, status, effectiveAt, endsAt, limits
  facilities/{facilityId}: name, location, status
    memberships/{uid}: facilityRole, permissions
    pluginInstances/{pluginId}: enabled, configuration, state
    sites/{siteId}: siteName, gatewayId, vpnId, status
    devices/{deviceId}: pluginId, siteId, deviceType, modelProfileId,
      ip, port, modbusUnitId, name, limits, commissioned, desiredControlEnabled
    telemetry/{deviceId}: gateway controlled only, timestamp, quality,
      readback values
    commands/{commandId}: immutable client request and gateway-controlled
      execution state (or subcollection per device)
    audit/{eventId}: immutable server authored actions
```

Existing app uses `facilities/{facilityId}` and global `users/{uid}.role`.
**Do not migrate or overwrite live data** until compatible tenant rules and
migration plan are reviewed. The prototype VACON implementation retains
`facilities/{facilityId}/vaconPumps` and `vaconPumpCommands`; future steps
may introduce abstractions and migration compatibility.

## Architectural boundaries

Flutter (Web/Android) = presentation, authentication, facility picker,
device list, read-only telemetry and submission of command intents.
No direct Modbus access from web; browser cannot open raw TCP sockets.

Billing/licensing service = authoritative entitlements with webhooks and
server-side verification. Payment status may toggle availability of NEW
remote control commands but must **never** abruptly change a running pump's
physical state. Local drive safety policy remains independently operational.

Trusted, always-on gateway service = VPN connectivity and **exclusive**
Modbus control for site devices. Supports several devices/IPs per site and
model-specific capabilities. Gateway authenticates to backend with short-lived
credentials/least privilege and sends authenticated telemetry. Never connect
to PLC/drive directly from a public internet endpoint.

Backend command handler = validates user membership, explicit `pump.control`
permission, org/facility plugin subscription, commissioning flags, freshness,
per-device control range, interlocks, command expiry, rate limits. The trusted
gateway must RE-CHECK live conditions before touching Modbus registers.

VACON adapter layer = a transport-independent per-model profile:
- model ID, firmware compatibility, Ethernet/option-card prereqs
- Modbus unit ID, addressing convention and register width/word ordering
- status decoding / alarms / actual and reference Hz scaling
- control word, reset handling, source selection, remote/local flag
- model-specific supported operations (capabilities)
- validated setpoint limits / watchdog and safe comms-loss behavior

Never send raw arbitrary register-write requests from app clients.
Never map unknown VACON models to a guessed register layout.
Unknown device = read-only, not commissioned.

## State and error semantics

Connectivity: disconnected | connecting | connected | stale | fault
Control: local | remote_ready | remote_blocked | not_commissioned
Command: queued | claimed | rejected | expired | applied_unverified |
  verified | failed
App must show separate `requested`, `accepted`, `verified from telemetry`
states. START/STOP never automatically retried after disconnect without a
fresh read of physical state.

## Licensing / UX

Main nav: Plugins
- Catalogue: Fjellfisk core (included), VACON Control (upgrade),
  OxyGuard (upgrade)
- My facility subscriptions
- Sites / VPN connectors
- Device inventory: many VACON model profiles per facility
- Permissions/audit and commissioning

Offer subscriptions per organization or facility as a future explicit product
choice; preserve the ability to associate entitlements at facility level. Do
not implement billing/provider/webhooks until selected and compliance reviewed.

## Rollout plan

1. Create `PluginDefinition`, `PluginEntitlement`, `SiteGateway`,
   `Device`/profile interfaces and a user-friendly facility selector.
2. Keep VACON prototype disabled (read-only demo until fully tested).
3. Build trusted simulated gateway, model-specific register profiles and
   command-processing unit tests for many devices (isolated by facility).
4. Select billing provider, integrate webhook entitlement updates only after
   billing design approved.
5. Add actual model profile once label/firmware/register manuals verified.
6. Deploy to staged nonproduction Firebase environment.
7. Qualified technician onsite end-to-end interlock, VPN loss/replay,
   telemetry and command tests.
8. Activate only vetted commissioned drives, gradually per facility.

## Required tests

- Two facilities cannot read/control one another's drives.
- Three VACON devices within one facility, distinct model profiles, IPs and
  data streams, have correctly isolated commands and audit.
- Concurrent requests to same unit serialize; different devices stay isolated.
- Expired/unlicensed user cannot enqueue/write (including direct API).
- Lease expiration does NOT generate a STOP or alter any active drive.
- Unknown model, stale telemetry, VPN outage, cloud delay, device restart
  or duplicated command cannot accidentally energize/accelerate a pump.
- Manual stop, hardwired interlocks and local control retain priority.

## IMPORTANT CURRENT GAP

Current `lib/main.dart` opens `DashboardScreen(facilityId:
'default_facility')` and users have global `admin/ansatt/leser` roles.
**Multi-tenant onboarding and facility-scoped access are NOT yet built**.
The first VACON branch is an incremental scaffold, NOT the finished commercial
multi-facility platform.
