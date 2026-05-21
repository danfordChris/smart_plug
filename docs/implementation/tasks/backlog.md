# Backlog

## Status

pending

## Objective

Track execution work for the first production release of `smart_plug`.

## Implementation Checklist

- [ ] Finalize the project-definition patch across `docs/design` and workflow-facing docs.
- [ ] Baseline the Raspberry Pi host: updates, locale, time sync, Docker, firewall, SSH key migration.
- [ ] Deploy Home Assistant Container with persistent storage and restart policy.
- [ ] Onboard the SonOFF S60TPG on the stock-firmware path through eWeLink and SonoffLAN.
- [ ] Validate local control, entity state, and practical telemetry under a known load.
- [ ] Build the initial Home Assistant dashboard, outage notification path, and automations.
- [ ] Define and test backup, restore, and operator recovery procedures.
- [ ] Run the stock-vs-reflash decision gate based on documented acceptance criteria.
- [ ] Prepare and complete go-live review for the one-home production deployment.
