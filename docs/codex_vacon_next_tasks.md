# Codex handoff: Fjellfisk plugin marketplace / multiple VACON drives

Work off `develop` into a separate branch. Inspect draft PR #20
(`feature/vacon-remote-pump-scaffold`) for the pre-site UI/Modbus scaffold.
Read `docs/plugin_platform_architecture.md` and
`docs/vacon_remote_pump.md` before coding.

## Mission
Refactor VACON scaffold toward a reusable multi-tenant plugin platform where
each organization/facility may license optional plugins independently and may
configure *many* VACON drives, including different supported model profiles.
Base Fjellfisk and optional VACON/OxyGuard subscriptions have separate pricing,
but do NOT invent or embed prices or select a payment provider.

## Tasks in order
1. Audit existing facility/role model and rules. Write a backward-compatible
   migration design; current app hardcodes `default_facility`.
2. Design typed `Device`, `DeviceModelProfile`, `SiteGateway` and
   `PluginEntitlement` models. Make device IDs and requested commands
   facility/site scoped and non-confusable.
3. Implement facility selection in Flutter with safe membership checks.
4. Implement plugin catalogue with VACON upgrade stub, OxyGuard
   upgrade stub (do NOT touch existing OxyGuard/Vigo integrations),
   per-facility entitlement badges. No billing side effects.
5. Replace simple VACON pump list with facility-scoped device inventory
   supporting multiple units and model profile selection. Unknown
   models must have no control capability.
6. Create a trusted gateway worker for simulated/non-live operation:
   per-drive read-only poller, command claiming, TTL check,
   role/license reauthorization, strict model register whitelist,
   serialized writes, readback verification and audit.
   Treat real hardware control as **disabled** until commissioning.
7. Write Firestore rules tests and gateway integration tests:
   multiple facilities, different model profiles, access isolation,
   duplicate messages, stale data, VPN outage, expired entitlement.
8. Run format/analyze/tests and supply build logs and a PR into develop.

## Hard constraints
- No production deploy, no merge to main, no live Modbus writes.
- Never commit API keys, Firebase service account credentials, VPN configs,
  payment secrets, or actual customer network access data.
- Never use public TCP/502, and never confuse accepted command with
  actual motor state.
- PIN-free control uses existing authentication AND explicit machine-control
  access. An ordinary production employee should not gain control rights
  merely from existing role.
- Remote control requires authorized idling/commissioning and a
  qualified electrician/automation tech reviewing local safety logic.
- Keep all VACON model-specific register addresses TBD until reliable
  documentation is verified; no fabricated generic addresses.
- Do not refactor unrelated production dashboards or OxyGuard/Vigo code.
- Respect CONTRIBUTING_STUDENTS.md: PR review by repository owner.

## Definition of done for pre-visit phase
- Flutter web/Android screens navigate correctly, compile and show
  multi-device simulated telemetry with unambiguous command state.
- Firebase emulator verifies strict tenant, entitlement and role rules.
- Gateway simulation handles read + (simulated) write flow end-to-end.
- Human-readable, offline-usable on-site checklist and rollback procedure.
- Real hardware commands remain locked until formal commissioning.
