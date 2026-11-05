# Fjellfisk Collector installer

`FjellfiskCollectorSetup.iss` builds a normal Inno Setup 6 installer for the
Production Collector only. It does not read VIGO.PRO, discover sensors, create
a Windows service, or alter OxyGuard/P-NET/Vigo configuration.

## Install layout

- Program files: `C:\Program Files (x86)\Fjellfisk\Collector\`
- Persistent state: `C:\ProgramData\Fjellfisk\SensorCollector\`

The persistent state contains `config`, `identity`, `logs`, and `buffer`.
Upgrade and repair are performed by rerunning a newer or the same setup file
with the same Inno Setup AppId. The installer replaces program binaries but
never overwrites or recreates ProgramData, so an existing collector identity is
preserved.

Normal uninstall removes only program files and the Windows uninstall entry.
It asks whether to remove the collector data and identity. **No** is the
default, including silent uninstall. Selecting **Yes** removes only the exact
Collector ProgramData directory above.

## Pairing and autostart

The build requires one explicit HTTPS pairing backend URL. The installer writes
that URL to `config\pairing-backend.json` only on a fresh install; it never
overwrites an existing configuration during repair or upgrade.

The installer creates the `Fjellfisk Collector` Scheduled Task for the
installing interactive user. It starts the Production Collector with
`--run` 60 seconds after that user logs in, runs at limited privilege, and
is removed on uninstall. There is no Windows service, Run registry entry, or
sensor read started by setup itself.

## Version and signing

Version 1.0.4 keeps the pairing window open when a code expires and replaces
the code in that same window. Closing the window programmatically waits for
the PairingUi child to exit before a later window can reuse IPC resources.
The test suite includes real child-process rotation and reconnect coverage.
No identity, backend URL, installer AppId, or uninstall behavior is migrated.

The Production project `<Version>` is the product and setup display version.
`Build-Installer.ps1` passes that version to Inno Setup and derives a four-part
Windows version resource value. `FjellfiskBuildId` remains separate build
metadata.

Signing is optional but ready for a real certificate. Provide both a certificate
thumbprint and timestamp URL to `Build-Installer.ps1`; it then calls the
existing `scripts\Sign-Collector.ps1` for the Production EXE and setup EXE.
The repository contains no certificate, private key, or fallback test signing.

## Build

From this directory, after a normal Production publish:

```powershell
.\Test-InstallerLayout.ps1
.\Build-Installer.ps1 -PairingBackendUrl https://api.tosprotein.com/collector/v1
```

`Build-Installer.ps1` locates Inno Setup 6 at either standard installation
path and refuses to install it automatically. It builds to `installer\output\`
but never runs the generated setup.

Before customer distribution, test fresh install, same-version repair, upgrade,
normal uninstall, and explicit data removal in an isolated Windows VM.
# 1.0.6: bounded stalled-reader recovery

Version 1.0.6 retains the existing 60-second interactive login task and uses a
single parent Collector process with one isolated read-only worker. A VIGO.PRO
timeout marks the worker as stalled, writes the existing safe local diagnostic,
uploads one final failed batch, and exits only that worker. The parent waits for
the worker process to exit before a replacement is considered. Recovery waits
60 seconds and is limited to three restarts in fifteen minutes; the Collector
then stops and requires an operator check. Neither VIGO nor P-NET is restarted,
and existing identity, pairing, configuration, buffer and mappings are not
modified.

# 1.0.5: read-only sensor collection

The login task retains its 60-second delay, but now runs `--run`: pairing first,
then sequential discovery-allowlisted sensor reads and authenticated HTTPS uploads.
`--pairing` remains a pairing-only diagnostic/start path and never reads sensors.
Installation does not start a sensor read; the task starts at the next login, or
an operator can start the task after upgrading. No Windows/VIGO restart is needed.

Upgrade over the installed version; do not uninstall or delete ProgramData.
AppId, backend configuration, DPAPI identity, pairing credential, logs and buffer
remain in their existing locations. Existing secure uninstall semantics are kept.
The production URL is supplied by the existing build/config mechanism.

Sampling is 15 seconds after each sequential round, only after a fresh PAIRED
status. No server-supplied PhysIds, setpoints or control operations are accepted.
COM failures do not restart or reconfigure VIGO/P-NET. Failed uploads retry with
15-300 second backoff, retaining stable batch UUIDs in a bounded local queue
(300 files / 50 MiB). A full queue pauses collection rather than deleting recent
unsent data. Batches older than seven days expire to match server acceptance.
Pairing/telemetry logs rotate at 2 MiB with three retained archives.

Only Production Collector and PairingUi are packaged. Sensor runtime, network
retries, restart identity, API authorization and mapping persistence must be
validated with test doubles/disposable databases before using the installer on
an OxyGuard PC. Do not run live COM tests from a development PC.
