# IPF Generator Skill

Use this skill to add or update generated models in a project-neutral way.

## Add generator entry

```dart
class _Item extends BaseModelGenerator {
  _Item() : super.database('item', {
    'id': int,
    'name': String,
    'createdAt': String,
  });
}
```

Register in `main()` generator list:

```dart
List<BaseModelGenerator> generator = [
  _Item(),
];
```

## Run

```bash
make ipf_gen
```

## Concrete model template

```dart
import 'package:your_app/starter_models/item_model.g.dart';

class ItemModel extends ItemModelGen {
  factory ItemModel.fromDatabase(Map<String, dynamic> map) => ItemModelGen.fromDatabase(map);
  factory ItemModel.fromJson(Map<String, dynamic> map) => ItemModelGen.fromJson(map);
}
```

## Rules

- Do not edit generated `.g.dart` files manually.
- Use primitive field types in generator schema.
- Register DB-backed models in database manager.
