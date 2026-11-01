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
`--pairing` 60 seconds after that user logs in, runs at limited privilege, and
is removed on uninstall. There is no Windows service, Run registry entry, or
sensor read started by setup itself.

## Version and signing

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
