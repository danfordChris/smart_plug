# iPF Flutter Starter Pack — Project Setup

Use this skill when initializing a new Flutter project using `ipf_flutter_starter_pack`.

## 1. pubspec.yaml dependency

Prefer the local starter-pack path when it exists on the machine running the generator.

```yaml
dependencies:
  ipf_flutter_starter_pack:
    path: /Users/danfordchris/projects/iPF_Flutter_Starter_Pack
```

If the local path is not available, fall back to the git dependency:

```yaml
dependencies:
  ipf_flutter_starter_pack:
    git:
      url: https://github.com/iPFSoftwares/iPF_Flutter_Starter_Pack.git
      ref: main
```

## 2. Install Claude skills into this project

```bash
dart run ipf_flutter_starter_pack:initialize_skills
```

Fallback for older starter-pack versions:

```bash
dart run ipf_flutter_starter_pack:install_skills
```

## 3. Required project setup

- Add `go_router`, `provider`, and `flutter_dotenv`.
- Add Android network permissions and core library desugaring.
- Update the iOS bundle identifier and display name.
- Generate project-level `AGENTS.md`, `CLAUDE.md`, `.claude/commands`, and `.claude/skills`.

## 4. main.dart initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AppDatabase.instance.init();
  AppNotificationService.instance.init();
  runApp(MultiProvider(providers: appProviders, child: const ProjectApp()));
}
```

## 5. Available skills

- `/ipf-api` - HTTP requests, auth headers, SSL pinning, multipart uploads
- `/ipf-database` - SQLite CRUD, migrations, encryption
- `/ipf-state` - Provider state with BaseDataProvider
- `/ipf-preferences` - SharedPreferences and SecureStorage
- `/ipf-notifications` - Local push notifications
- `/ipf-utils` - Navigation, AppUtility, SocketManager
- `/ipf-widgets` - BaseTextField, BaseButton, BaseImage, BaseDropdown
- `/ipf-extensions` - String, DateTime, Number, BuildContext extensions
- `/ipf-security` - SSL pinning, digital signatures
- `/ipf-codegen` - Model and repository code generation
