# Repository Guidelines

## Project Structure & Module Organization

ScamShield is a Flutter application. Product code lives in `lib/`, organized by responsibility: `screens/` for routes and UI flows, `widgets/` for reusable components, `models/` for data types, `services/` for classification, notifications, and Supabase access, and `theme/` for shared styling. Automated tests are in `test/`. Platform-specific runners and configuration are under `android/`, `ios/`, `web/`, `macos/`, `windows/`, and `linux/`. Supabase schema changes belong in `supabase/migrations/`.

## Build, Test, and Development Commands

- `flutter pub get` resolves Dart and Flutter dependencies.
- `flutter run` launches the app on an available device or emulator.
- `flutter analyze` runs the configured Dart and Flutter lints.
- `flutter test` runs the test suite in `test/`.
- `flutter build apk` creates an Android APK; use `flutter build <platform>` for other supported targets.

Run commands from the repository root. Configure Supabase credentials through the app's expected local setup; never commit secrets.

## Coding Style & Naming Conventions

Follow `analysis_options.yaml` and the `flutter_lints` rules. Use standard Dart formatting (`dart format lib test`), two-space indentation, `snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Keep widgets, models, and service logic in their corresponding `lib/` directories; prefer focused components over large screen files.

## Testing Guidelines

Tests use `flutter_test` and live in `test/`; name files `*_test.dart`. Add or update tests for behavior changes, especially classification decisions, message flows, and service-facing state. Run `flutter test` and `flutter analyze` before submitting changes.

## Commit & Pull Request Guidelines

Recent history uses short imperative summaries, sometimes with conventional prefixes such as `feat:`. Keep commits focused and describe the user-visible change (for example, `feat: improve message risk details`). Pull requests should explain the behavior and motivation, note relevant tests and configuration or migration changes, link related issues, and include screenshots for UI changes.

## Security & Configuration

Do not commit API keys, tokens, or production credentials. Review Supabase migrations for access controls and data exposure, and keep generated platform files and dependency lockfiles consistent with the project's Flutter tooling.
