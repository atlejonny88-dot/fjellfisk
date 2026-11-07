# Pelasyn Host Stability Observation

Observed read-only on 7 November 2026. This is an operational record, not a
remediation runbook and does not authorize changes to BIOS, kernel, network or
containers.

## Evidence

- The host is a Dell Precision 7550 running Ubuntu 26.04.1 with kernel
  `7.0.0-42-generic` and firmware `1.12.0` from December 2021.
- The current boot followed an unclean journal shutdown. That establishes a
  restart occurred, but does not prove the cause of a host freeze.
- During the current boot, `cdc_mbim` repeatedly logged `NETDEV WATCHDOG`
  transmit timeouts of roughly five to six seconds on
  `wwp0s20f0u2c2`. They recurred for many hours. The interface was `DOWN`
  at inspection time.
- Kernel workqueues also reported occasional slow `acpi_ec_event_processor`
  and `e1000e_watchdog_task` runs. These are secondary observations, not a
  diagnosed root cause.
- There was no out-of-memory event, swap use, low disk space or Fjellfisk
  backend error. At inspection, PostgreSQL and `fjellfisk-backend` were both
  healthy; the backend remained bound to `127.0.0.1:8080` and PostgreSQL had
  no host port.

## Interpretation

The repeated `cdc_mbim` watchdog is the strongest documented stability risk.
It can disrupt networking and may contribute to perceived freezes, but the
read-only evidence does not prove that it caused each prior host lockup.

## Safe Next Steps Requiring Separate Approval

1. Confirm which network path is intended for normal server operation; prefer
   the wired interface when that is available and stable.
2. During a planned maintenance window, collect a before/after journal around
   any recurrence before disabling or reconnecting the USB MBIM device.
3. Review Dell's supported BIOS and Linux firmware updates for the Precision
   7550, then schedule any update with a verified backup and physical access.
4. If the fault recurs, preserve `journalctl -b -1 -k` and hardware event
   timestamps before rebooting. Do not infer a VACON or Edge fault from a host
   freeze without this evidence.

No configuration was changed while making this observation.
