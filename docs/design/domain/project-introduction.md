# Project Introduction

## Overview

`smart_plug` is a home automation control and monitoring project centered on one Raspberry Pi 5 and one SonOFF S60TPG Wi-Fi smart plug.

The Raspberry Pi is the production controller for the home deployment. It runs the automation platform, hosts the local dashboard, stores configuration and operational state, and acts as the integration point between the local network and the smart plug.

The first release is intentionally narrow. It must control one plug reliably, expose useful power telemetry, recover from routine restarts, and give the operator enough visibility to treat the system as a production home service rather than a one-off experiment.

The project must also remain extensible. The initial implementation targets one plug, but the repo structure, design docs, and operational model should support adding more smart plugs or related devices later without rewriting the foundation.

## Current Hardware

- Raspberry Pi 5
  - Hostname: `smart`
  - OS: Debian 13
  - Access: `ssh smart@192.168.1.19`
  - Role: single production host
- Smart plug
  - Vendor: SonOFF
  - Model: S60TPG
  - Transport: Wi-Fi
  - Initial firmware assumption: stock eWeLink-managed firmware
- Network
  - One home LAN
  - Raspberry Pi and plug are expected to remain on the same local network segment

## Target User And Operator

The initial user and operator are effectively the same person: the home administrator who owns the Raspberry Pi, manages the plug, and maintains the deployment.

This operator needs a system that is understandable, recoverable, and predictable. The project should not require undocumented rituals, hidden cloud dependencies, or repeated manual repairs after normal failures such as host reboot, service restart, or temporary WAN loss.

## Problem Being Solved

The project exists to turn a consumer smart plug into a dependable home-controlled service with:

- a local control interface
- reliable switching behavior
- usable power and energy visibility
- documented recovery and maintenance procedures

The problem is not just “connect a plug.” The real problem is creating a production-grade home setup where the Raspberry Pi, automation platform, and device integration behave like a maintainable system.

## Target Outcome

The first production release should deliver:

- local dashboard access for the plug
- reliable on/off control from the controller
- visibility into power, current, voltage, and energy data where supported
- automatic recovery after host or service restart
- alerts when the device or service becomes unavailable
- documented backup, restore, and troubleshooting procedures

Production does not mean global scale or multi-tenant support. It means one home deployment that is stable enough to trust for daily use.

## How The System Works

The Raspberry Pi runs the automation platform and remains the central control point.

Home Assistant is the primary application. It owns dashboards, automations, entity state, alerts, and the operational view of the smart plug.

The SonOFF S60TPG is integrated first through SonoffLAN while still on stock firmware. This path starts with eWeLink onboarding, then exposes the plug to Home Assistant. The preferred steady-state behavior is local control over the home network. Cloud fallback is tolerated only as an interim dependency or fallback path and is not accepted as the final reason the system works.

The operator interacts with the system through Home Assistant on the LAN. The operator should be able to view the plug state, inspect live telemetry, trigger automations, and understand failures without needing to reverse-engineer the deployment.

## Day-To-Day Usage

Normal usage is expected to include:

- checking whether the plug is on or off
- turning the plug on or off from the local dashboard
- viewing live power draw and recent energy usage
- receiving an alert if the plug becomes unavailable
- relying on scheduled or policy-based automations

Normal operations should not require SSH access. SSH is an admin and recovery tool, not the primary user interface.

## Production Expectations

For this repo, production means:

- the Raspberry Pi is reachable and stable on the LAN
- Home Assistant starts automatically and persists configuration
- the plug remains controllable without manual recovery steps
- telemetry is good enough for practical monitoring
- backup and restore procedures exist and are documented
- operator runbooks exist for common failures
- the system passes explicit acceptance checks before being called complete

The project does not assume:

- public exposure of Home Assistant to the internet
- a separate custom mobile app
- multi-home or multi-tenant support
- that stock SonOFF firmware is guaranteed to be the final production path

## Success Criteria For The First Production Release

The first production release is successful when:

- the Raspberry Pi can reboot and recover the service automatically
- Home Assistant remains reachable on the LAN
- the plug can be switched reliably from Home Assistant
- state remains synchronized after restart and routine use
- telemetry updates are usable for real monitoring
- an outage or device-unavailable condition is surfaced to the operator
- a backup exists and the restore process is documented

## Known Risks

- Stock SonOFF firmware may not provide sufficiently reliable local telemetry.
- SonoffLAN may require cloud credentials for onboarding or fallback behavior.
- Home Assistant Container requires the operator to manage the Linux host and companion services directly.
- The Raspberry Pi is a single production host and therefore a single point of failure until stronger redundancy is added.

## Future Expansion

The repo should be able to grow to support:

- additional smart plugs
- additional rooms or circuits
- richer energy tracking
- more notification channels
- more device categories

That expansion should build on the same design layers and operating model defined for the first plug rather than replacing them.
