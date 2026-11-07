# Obfuscation and signing readiness

No obfuscator is enabled yet. Select a standard .NET obfuscator only after a
signed production build has passed a real VIGO compatibility test.

The following must be preserved from renaming and string encryption:

- `VIGO.PRO` ProgID and the `PhysId`, `Value`, and `ErrorCode` COM member
  strings used by `VigoComScalarReadSession`.
- Production entry point and `Fjellfisk.SensorCollector.exe` assembly name.
- Public JSON property names for `CollectorBatch`, `CollectorReading`,
  `ProductionDiscoveryResult`, discovery cache models, and identity documents.
- DPAPI entropy string and `identity.json`/persistent storage contracts.
- Installer file names and code-signing target names.

The Internal Service Tool additionally needs its diagnostics COM type-info
interfaces preserved. Do not obfuscate first and discover breakage on a live
OxyGuard PC.

`scripts\Sign-Collector.ps1` is a manual Authenticode hook. It accepts a
certificate thumbprint from the Windows certificate store and a timestamp URL;
it stores no certificate, private key, password, or secret in the repository.
