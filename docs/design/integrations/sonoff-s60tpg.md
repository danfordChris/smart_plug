# SonOFF S60TPG Integration Strategy

## Overview

The initial production device for `smart_plug` is a SonOFF S60TPG Wi-Fi smart plug.

The default integration path keeps the stock device firmware and brings the plug into Home Assistant through SonoffLAN after onboarding it with eWeLink. This path is the least invasive starting point and should be attempted first.

The project does not assume that stock firmware will automatically qualify for final production use. Stock firmware is accepted only if it provides stable control and usable local telemetry under the production acceptance tests.

## Initial Device Path

The initial expected path is:

1. onboard the plug in eWeLink
2. attach the plug to the home Wi-Fi network
3. add the device to Home Assistant using SonoffLAN
4. configure SonoffLAN in `auto` mode
5. validate local control and local telemetry behavior

## Why SonoffLAN Is The Starting Point

SonoffLAN provides the shortest path from a stock SonOFF device to Home Assistant while preserving the possibility of local LAN control.

It fits the initial goals because it can:

- expose the plug as a Home Assistant entity
- support local control when the local path works
- preserve a fallback path during early validation

## Required Steady-State Behavior

The first production release must achieve:

- reliable plug switching from Home Assistant
- synchronized device state
- telemetry that is practical for operator monitoring
- acceptable behavior after Home Assistant restart or host reboot
- acceptable behavior when the WAN is unavailable

The project treats local-first operation as the target steady state.

## SonoffLAN Mode Choice

The starting configuration is `auto` mode.

Rationale:

- it prefers local communication when available
- it keeps a fallback path during early deployment and validation
- it allows the project to prove whether the stock path is viable before escalating to more invasive options

The project should not consider cloud dependence alone to be a production-quality outcome.

## 2026 Telemetry Risk

The integration strategy must explicitly account for the current SonoffLAN limitation that cloud-based power, current, and voltage updates are no longer a reliable live-telemetry path in 2026.

As a result:

- cloud-only telemetry is not acceptable for final production
- stock firmware is considered successful only if local telemetry updates meet practical monitoring needs
- if the plug remains controllable but telemetry is stale or cloud-limited, the stock path fails the production decision gate

## Required Entities And Behaviors

The Home Assistant integration should expose, where supported:

- plug switch state
- availability or connection state
- power
- current
- voltage
- energy counters such as daily or monthly readings

The exact entity set may vary by device behavior and integration support, but live power visibility is part of the target outcome.

## Acceptance Criteria For Stock Firmware

Stock firmware is accepted as the production path only if:

- switching is reliable
- entity state remains synchronized
- power telemetry updates in a practically useful way under a known load
- the system recovers normally after service restart
- the local path remains usable during WAN interruption for at least control operations

## Fallback Decision Order

If the stock path fails, the fallback order is:

1. reject stock firmware as the final production path
2. evaluate a controlled reflash pilot on a non-production or sacrificial unit
3. if reflash is unsafe or not repeatable, replace the hardware with a better-supported local-first plug

This fallback order is part of approved design truth and should not be improvised later in status notes.

## Reflash Path Expectations

If reflash becomes necessary, it must be treated as a controlled engineering decision, not a casual tweak.

Requirements before approving a reflash rollout:

- one pilot unit first
- stock firmware backup captured where possible
- documented flashing and recovery steps
- repeatable local control and telemetry after reflash
- acceptable electrical safety and enclosure reassembly

If those conditions are not met, the project should prefer hardware replacement over forcing a brittle firmware path.
