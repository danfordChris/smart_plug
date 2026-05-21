# Add Notification Skill

Use this skill to add a new push notification type in a generic feature-safe way.

## Steps

1. Add enum value in `NotificationType` with backend ID.
2. Extend payload model with any additional fields.
3. Add routing/action handling in notification action controller.
4. Ensure target route exists.

## Example

```dart
enum NotificationType {
  general(0),
  itemUpdated(1);

  final int id;
  const NotificationType(this.id);
}
```

```dart
case NotificationType.itemUpdated:
  if (payload.itemId != null) {
    context.push('/item/${payload.itemId}');
  }
  break;
```

## Rules

- Keep payload parsing defensive (`null` safe).
- Keep notification routing centralized.
- Avoid feature-specific naming in shared templates.
