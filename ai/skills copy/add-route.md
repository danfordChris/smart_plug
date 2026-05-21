# Add Route Skill

Use this skill to add a route using generic examples.

## Add enum route

```dart
enum AppRoute {
  itemDetails('/item/:itemId'),
  itemCreate('/item/create');

  const AppRoute(this.path);
  final String path;
}
```

## Add GoRoute

```dart
GoRoute(
  path: AppRoute.itemDetails.path,
  builder: (context, state) {
    final itemId = int.parse(state.pathParameters['itemId']!);
    return ItemDetailsScreen(itemId: itemId);
  },
),
```

## Navigate

```dart
context.push(AppRoute.itemDetails.path.replaceFirst(':itemId', '$id'));
context.go(AppRoute.itemCreate.path);
```

## Rules

- Do not hardcode route strings in UI.
- Keep route params and parser keys aligned.
- Keep modal/full-screen route behavior explicit.
