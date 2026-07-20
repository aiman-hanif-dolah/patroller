# Contributing to Patroller

Thanks for helping improve Patroller. Forks, issues, and pull requests are welcome.

## Ground rules

- Be respectful and constructive.
- Prefer small, focused PRs over large mixed changes.
- Keep secrets and real credentials out of commits (use placeholders in tests and defaults).
- Match existing Dart / Flutter style and folder layout under `lib/`.

## Testing Flutter apps with Patroller

Patroller is a **runner/workbench**. Flutter apps you open still need full **Patrol native setup**:

- Android: `PatrolJUnitRunner` + `MainActivityTest` instrumentation
- iOS: **RunnerUITests** target + `RunnerUITests.m` + Test Plan / scheme + Pods

See **[Prepare your Flutter app for Patrol](README.md#-prepare-your-flutter-app-for-patrol)** in the README before filing "tests won't run" issues.

## Development setup

```bash
git clone https://github.com/aiman-hanif-dolah/patroller.git
cd patroller
flutter pub get
flutter run -d macos   # or: flutter run -d windows
```

Run unit tests:

```bash
flutter test
```

Optional: rebuild the DevTools panel after UI changes:

```bash
cd devtools_extension
flutter pub get
flutter build web --release --base-href=/panel/ --no-tree-shake-icons
perl -i -pe 's|<base href="/panel/"\s*/?>|<base href="/">|' build/web/index.html
rm -rf ../extension/devtools/build
cp -R build/web ../extension/devtools/build
```

## How to contribute

1. **Fork** the repository on GitHub.
2. Create a branch: `git checkout -b feature/your-idea`.
3. Make your changes and add or update tests when behavior changes.
4. Run `flutter test` (and a quick manual smoke on macOS/Windows if you touch UI).
5. Commit with a clear message.
6. Push to your fork and open a **Pull Request** against `main`.

## Good first issues

- UI polish and accessibility
- Windows parity improvements
- Docs and examples for Patrol project layout
- Health-check coverage for more toolchains (FVM, pure, asdf)
- Recording export / flow-editor edge cases

## Reporting bugs

Open an issue with:

- OS and Flutter version (`flutter --version`)
- Patrol CLI version (`patrol --version`) if relevant
- Steps to reproduce
- Expected vs actual behavior
- Logs or screenshots when possible

## Code of conduct

Assume good intent. Harassment or personal attacks are not acceptable. Maintainers may close issues or PRs that violate that spirit.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
