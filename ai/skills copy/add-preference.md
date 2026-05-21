# Add Preference Skill

Use this skill to add app preferences with reusable naming.

## Template

```dart
class FeaturePreferences extends BasePreferences {
  FeaturePreferences._();
  static final FeaturePreferences instance = FeaturePreferences._();

  Future<bool?> get enabled => fetch<bool>('feature_enabled');
  Future<void> setEnabled(bool value) => save('feature_enabled', value);

  Future<void> clearFeaturePrefs() async {
    await remove('feature_enabled');
  }
}
```

## Rules

- Use one singleton per preference class.
- Prefix keys by feature (`feature_*`).
- Clear feature/session scoped values on logout.
- Keep sensitive data in `BaseSecurePreferences`.
