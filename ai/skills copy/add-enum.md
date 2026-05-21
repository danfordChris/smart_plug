# Add Enum Skill

Use this skill to add reusable enums without project-specific naming.

## Pattern A: Label + Backend ID

```dart
enum EntityType {
  basic('Basic', 1),
  premium('Premium', 2); 

  final String label;
  final int id;
  const EntityType(this.label, this.id);

  static EntityType fromId(int id) => EntityType.values.firstWhere(
        (e) => e.id == id,
        orElse: () => throw ArgumentError('Unknown EntityType id: $id'),
      );
}
```

## Pattern B: Localized label

```dart
enum ActionStatus {
  pending,
  active,
  completed;

  String get label => switch (this) {
    ActionStatus.pending => Strings.instance.statusPending,
    ActionStatus.active => Strings.instance.statusActive,
    ActionStatus.completed => Strings.instance.statusCompleted,
  };
}
```

## Rules

- Use `switch` expressions for exhaustive mapping.
- Add `fromId` for API-backed enums.
- Keep enum names domain-neutral in templates.
