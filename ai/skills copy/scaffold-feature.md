# Scaffold Feature Skill

Use this skill to scaffold a new feature module with neutral naming.

## Structure

```text
lib/features/<feature>/
  enum/
  helper_model/
  model/
  providers/
  screens/
  service/
  widgets/
```

## Order

1. Create model(s) or generator entries if needed.
2. Create service with API methods.
3. Create provider and register it.
4. Add localization keys.
5. Add feature screens/widgets.
6. Add routes.

## Minimal provider + screen flow

- Provider exposes loading + data state.
- Screen calls provider in post-frame callback.
- UI consumes provider via `context.watch/select`.

## Checklist

- [ ] Feature folders created
- [ ] Service implemented
- [ ] Provider implemented and registered
- [ ] Routes added
- [ ] Localized strings added
- [ ] Shared vs feature widget placement reviewed
