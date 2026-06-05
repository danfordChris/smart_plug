# System Architecture

## Overview

The `smart_plug` system is a single-home automation deployment hosted entirely on one Raspberry Pi 5. The Raspberry Pi is the only production host in the initial release and is responsible for running the automation platform, storing configuration and state, and exposing the local control surface for the smart plug.

The architecture is intentionally simple:

- one Raspberry Pi host
- one primary application platform
- one initial plug integration
- one local network

This keeps the first production release understandable and supportable while leaving room for future expansion.

## Host Model

- Host hardware: Raspberry Pi 5
- Host OS: Debian 13
- Host network identity:
  - hostname: `smart`
  - address: `192.168.1.19`
- Host role: dedicated production controller for this home automation deployment

The host is preserved as Debian rather than being reimaged. This is a deliberate tradeoff:

- Home Assistant OS is generally the recommended installation type
- this repo preserves an already running Debian host
- the project accepts responsibility for host maintenance, Docker lifecycle, and companion services in exchange for keeping the existing system intact

## Runtime Model

The runtime is based on Docker.

Primary application:

- Home Assistant Container

Potential companion services, only if needed later:

- VPN client for remote admin
- backup sync helper
- MQTT broker if a reflash path is activated

The initial production path does not require companion services beyond Home Assistant Container itself.

## Service Boundaries

### Host responsibilities

The Debian host is responsible for:

- network presence on the LAN
- Docker runtime
- persistent storage
- firewall and SSH policy
- service startup after reboot
- time synchronization

### Home Assistant responsibilities

Home Assistant is responsible for:

- dashboards
- automations
- entity state
- alerts
- integration configuration
- operator-facing monitoring of the plug

### Device integration responsibilities

The integration layer is responsible for:

- connecting the SonOFF plug into Home Assistant
- exposing switch state
- exposing live telemetry where supported
- preserving a local-first control path whenever possible

## Persistent Storage

Persistent storage must live on the Raspberry Pi host, not only inside the container.

At minimum, persistent host directories are required for:

- Home Assistant configuration
- Home Assistant state and integration data
- backup artifacts
- deployment and operational scripts if added later

The architecture assumes that container recreation must not destroy application state.

## Network Assumptions

The production design assumes:

- the Raspberry Pi and SonOFF plug share the same home LAN
- the Raspberry Pi is connected over Ethernet
- the plug uses Wi-Fi
- mDNS or equivalent local discovery traffic is available if needed by the integration path
- the deployment does not rely on public inbound internet exposure

The architecture should treat flat-LAN reachability and stable local addressing as operational prerequisites.

## Access Model

### Primary user access

The primary interface is the Home Assistant web UI on the local network.

### Administrative access

Administrative access is through SSH to the Raspberry Pi and container management on the host.

SSH exists for:

- deployment
- maintenance
- troubleshooting
- recovery

It is not the daily-use control path.

### Remote access

Remote admin, if enabled later, should be VPN-first. Public port forwarding is not part of the base architecture.

## Restart And Recovery Behavior

The system is expected to recover automatically from:

- host reboot
- Home Assistant container restart
- routine service recreation

This means:

- Docker must start on boot
- Home Assistant Container must restart automatically
- persistent config must survive container replacement
- the plug integration must be able to reconnect without manual intervention in normal cases

## Operational Constraints

Home Assistant Container is a valid runtime for this repo, but it comes with explicit constraints:

- no Home Assistant OS supervisor model
- no add-on ecosystem
- host maintenance is the operator’s responsibility
- any supporting services must be managed separately on the Debian host

These constraints are acceptable because the current project scope is small and the host is intentionally preserved.

## Reliability Goals

The architecture for the first release is considered acceptable only if it supports:

- stable LAN access
- reliable plug switching
- practical telemetry visibility
- backup and recovery
- understandable failure isolation between host, Home Assistant, and the smart plug

## Expansion Model

Future expansion should remain compatible with this architecture by:

- adding more devices through Home Assistant
- adding more automations and dashboards within the same control plane
- adding helper services only where justified

The architecture should not assume a rewrite when the project moves beyond one plug.
