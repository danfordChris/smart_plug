# API Service Skill

Use this skill to build feature services with generic patterns.

## Template

```dart
class FeatureService {
  FeatureService._();

  static Future<List<ItemModel>> fetchAll() async {
    final response = await APIManager.instance.apiAuthGet(_Endpoints.fetchAll);
    response.log();
    response.raiseOnError();
    final data = response.responseBody['data'] as List;
    return data.map((e) => ItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ItemModel> fetchById(int id) async {
    final response = await APIManager.instance.apiAuthGet(_Endpoints.fetchById(id));
    response.log();
    response.raiseOnError();
    return response.mapData<ItemModel>(ItemModel.fromJson);
  }
}

class _Endpoints {
  _Endpoints._();
  static const String fetchAll = '/items';
  static String fetchById(int id) => '/items/$id';
}
```

## Rules

- Keep endpoints in private `_Endpoints` class.
- Always call `raiseOnError()` before transforming.
- Keep services static and stateless.
