# Fjellfisk VACON Edge

`fjellfisk-vacon-edge` is a facility-local Linux service for **read-only**
VACON 100 FLOW monitoring. It is not a Modbus gateway and it exposes no port.
It makes outbound TLS requests to Fjellfisk and sends only Modbus FC04 reads to
the configured drives.

## Safety boundary

- No Modbus write functions, control words, speed references, start, stop, or
  reset commands exist in this project.
- The edge supports only the documented `VACON 100 FLOW` FC04 process-data
  profile.
- Actual frequency is decoded from documented register 2104/PDU 2103 with
  `/100` scaling. RPM and motor-current scaling remain explicitly unverified
  until site commissioning confirms the process-data mapping.
- A `TEST_CONNECTION` command requests one read-only FC04 cycle. A browser
  never receives the Edge credential or a route to port 502.

## Provisioning and deployment

An operator first runs the server-side `provision:vacon-edge` script. It writes
a one-time `edge.json` credential bundle directly to a protected operator path.
Copy it to `/etc/fjellfisk-vacon-edge/edge.json`, owned by root and mode `0600`.
The `edgeServerId` in the Fjellfisk Add-on must equal that Edge's generated ID.

On the Pelasyn server, after a separate commissioning approval:

```bash
sudo install -d -m 0750 /etc/fjellfisk-vacon-edge /var/log/fjellfisk-vacon-edge
sudo install -m 0600 /secure/operator-path/edge.json /etc/fjellfisk-vacon-edge/edge.json
sudo cp deploy/fjellfisk-vacon-edge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now fjellfisk-vacon-edge
```

This repository does not run these commands or connect to a physical drive.

## Local tests

```powershell
cd tools/fjellfisk_vacon_edge
npm test
```
