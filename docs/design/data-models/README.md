# Data Models

Approved data-model truth (entities, fields, relationships). Source of truth for the gateway schema
and shared contracts.

Current models live in code (`services/plug-gateway/app/models.py`): User, RefreshToken, Invite,
DeviceConfig, Alert, Schedule, PushToken, PlugTelemetry, PlugTelemetryRollup.

Proposed additions (Meter, Token/Units, Appliance profiles, Loss, Document) are under review in
`docs/changes/proposed/system-requirements-alignment.md` and fold here on acceptance.
