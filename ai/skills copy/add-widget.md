# Add Widget Skill

Use this skill to create reusable widgets with project-agnostic naming.

## Reuse First

Before creating a new widget, check shared widget library in `lib/shared/widgets`.

## Shared Widget Template

```dart
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}
```

## Rules

- Use theme colors and text styles.
- Avoid hardcoded app-specific strings.
- Keep shared widgets generic and feature widgets in feature folders.
