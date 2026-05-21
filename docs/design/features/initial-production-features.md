# Initial Production Features

## Overview

The first production release focuses on one smart plug and the minimum feature set required to make the system useful, observable, and supportable in daily use.

These features define expected system behavior. They do not prescribe exact implementation details beyond what is needed to describe the product outcome.

## Local Dashboard

The system must provide a local dashboard through Home Assistant.

The dashboard should allow the operator to:

- see whether the plug is on or off
- view device availability
- inspect current telemetry values
- access the plug without SSH or manual service intervention

## Plug Control

The system must support reliable on/off control of the SonOFF S60TPG from the main control interface.

This includes:

- direct switching from the dashboard
- correct reflected state after a command
- usable behavior after restart and normal reconnection

## Power And Energy Visibility

The first release should expose the most useful available electrical metrics for the operator.

Target visibility includes:

- power
- current
- voltage
- daily energy usage where available
- monthly energy usage where available

The intent is not raw data collection for its own sake. The intent is practical visibility that helps the operator understand the plug’s behavior and load.

## Availability Monitoring

The system must show whether the plug is online and reachable.

Availability monitoring is part of the core release because a smart plug that disappears silently is not acceptable for production use.

## Outage Notification

The system should alert the operator when:

- the plug becomes unavailable
- the control service fails to see the plug for an unusual amount of time

The initial release does not require multiple notification channels. It requires at least one working operator notification path.

## Scheduled Automation

The system should support schedule-based control of the plug.

This allows the operator to use the plug as more than a manual toggle and establishes the baseline automation capability for the project.

## High-Load Awareness

The first release should allow optional alerting or automation based on unusually high power use.

This is optional at the feature level because the exact thresholds depend on the operator’s appliance and environment, but the system should be built with this use case in mind.

## Recovery-Oriented Behavior

The first release is expected to behave predictably after:

- Raspberry Pi reboot
- Home Assistant restart
- temporary loss of WAN connectivity

The operator should not need to rebuild the integration from scratch after routine failures.

## First-Release Success

The initial feature set is complete when the operator can:

- open the dashboard locally
- control the plug reliably
- observe practical telemetry
- receive an outage signal
- trust that normal restarts do not invalidate the setup
