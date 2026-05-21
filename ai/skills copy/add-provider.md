# Add Provider Skill

Use this skill to create a provider with neutral naming and reusable structure.

## Template

```dart
class FeatureProvider extends BaseProvider with LoggerMixin {
  bool _isFetching = false;
  List<ItemModel> _items = [];

  bool get isFetching => _isFetching;
  List<ItemModel> get items => _items;

  Future<void> fetchItems() async {
    try {
      _setFetching(true);
      _items = await FeatureService.fetchAll();
    } catch (e) {
      logError('fetchItems error: $e');
    } finally {
      _setFetching(false);
    }
  }

  void _setFetching(bool value) {
    _isFetching = value;
    notifyListeners();
  }
}
```

## Register

Add provider in `lib/shared/providers/providers.dart`.

## Rules

- Keep provider fields private.
- Keep networking in service layer.
- Do not call services directly from UI widgets.
