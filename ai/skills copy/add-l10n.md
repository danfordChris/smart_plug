# Add L10n Skill

Use this skill to add localized strings in a project-agnostic way.

## Files

- `lib/l10n/intl_en.arb`
- `lib/l10n/intl_sw.arb` (or your secondary locale)

## Key Pattern

Use feature-prefixed camelCase keys, for example:

```json
{
  "featureTitle": "Feature Title",
  "@featureTitle": {},
  "featureEmptyState": "No items found",
  "@featureEmptyState": {}
}
```

## Generate

```bash
flutter pub global run intl_utils:generate
```

## Usage

```dart
Text(Strings.instance.featureTitle)
Text(Strings.of(context).featureTitle)
```

## Rules

- Add keys in all supported locales.
- Do not hardcode user-facing strings in widgets/services.
- Do not edit generated localization files manually.
