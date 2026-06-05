# Security And Recovery

## Overview

The first production release is a home deployment, not an internet-facing SaaS system. The security model therefore prioritizes strong local administration practices, controlled remote access, secrets hygiene, and recovery clarity over public exposure or multi-user complexity.

The system must remain understandable and recoverable by the operator after routine failures, upgrades, or configuration mistakes.

## Exposure Model

The default exposure model is LAN-only.

Expected defaults:

- Home Assistant UI is reachable only from the local network
- SSH is reachable only from the local network
- no router port forwarding is configured for the service
- no public direct access path is required for normal operation

If remote admin is enabled later, the preferred model is VPN-first rather than publishing Home Assistant or SSH directly to the internet.

## SSH Expectations

SSH is the administrative recovery path for the Raspberry Pi.

Expected posture:

- password authentication is tolerated during initial bootstrap only
- key-based authentication becomes the steady-state access method
- root login should remain disabled
- only required administrators should retain access

SSH must be treated as production infrastructure, not an afterthought. If the operator loses dashboard access, SSH remains the path to inspect Docker, logs, backups, and runtime state.

## Home Assistant Account Expectations

Home Assistant is the primary operator-facing control plane and therefore must use strong administrative credentials.

Expected posture:

- unique admin password
- MFA where supported and practical
- no shared credentials if more users are added later

## Secrets Handling

Secrets must not be committed to the repo.

Expected secret classes include:

- Home Assistant admin credentials
- eWeLink account or integration credentials
- SSH private keys
- any backup sync destination credentials added later

Repo deliverables may include examples and secret variable names, but not real secret material.

## Backup Policy

The production system requires more than one copy of recoverable state.

Expected minimum policy:

- one local backup path on the Raspberry Pi
- one off-device copy path outside the Pi itself
- backup before major upgrades
- retention of multiple restore points instead of only the latest backup

The backup process must be documented well enough that another operator can follow it without guessing.

## Restore Expectations

The restore path must be documented as an ordered procedure, not implied.

At minimum, recovery documentation must cover:

- regaining host access
- confirming Docker runtime health
- restoring Home Assistant configuration and state
- re-establishing integration credentials if needed
- validating that the plug and key automations are back online

The project is not production-ready if backups exist but the restore path is ambiguous.

## Operator Emergency Kit

The operator must maintain an emergency kit containing the critical recovery information for the deployment.

It should include:

- Raspberry Pi hostname and IP
- SSH access method
- Home Assistant URL on the LAN
- location of backups
- restore procedure location
- credential recovery notes
- current known-good service version details where practical

The emergency kit may be digital, printed, or both, but it must remain accessible even if Home Assistant is down.

## Failure Domains

The design must help the operator distinguish failures across at least these domains:

- Raspberry Pi host failure
- Docker/runtime failure
- Home Assistant application failure
- SonoffLAN or integration failure
- smart plug connectivity failure
- WAN or vendor-cloud degradation

The recovery material should guide the operator toward isolating these causes instead of treating every incident as a generic outage.

## Production Readiness Expectations

The security and recovery posture is acceptable only if:

- the system is not exposed publicly by default
- SSH administration is hardened
- secrets are kept out of version control
- local and off-device backups exist
- the operator can perform a documented restore
- routine incidents can be diagnosed using the runbook
