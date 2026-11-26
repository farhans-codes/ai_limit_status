# Adding a provider

AI Limit Status ships with Codex, Claude, and Antigravity. Every other AI tool
is open for contribution: if you use one and can test it with your own account,
you can add it without touching the rest of the app.

A provider is four small pieces. The Antigravity provider is the shortest
complete example; search the code for `antigravity` to see each one.

## 1. Name it

Add a value to `UsageProvider` in
`lib/features/usage/domain/entities/provider_usage.dart`. The value's name is
the provider id: it is stored in settings and cache files and sent to the
native status code, so do not rename it later.

The analyzer now lists every `switch` that needs a case for the new value.

## 2. Describe it

Add a `ProviderDefinition` in
`lib/features/usage/presentation/provider_definition.dart`: display name
(from `lib/core/constants/app_strings.dart`), icon asset, colors, and whether
it is set up through a CLI.

Add the icon as a single-color SVG at `assets/icons/<id>.svg` and list it under
`assets` in `pubspec.yaml`. Use a mark you are allowed to distribute; official
logos stay the property of their owners and must be listed in `NOTICE.md`.

## 3. Read it

Write a class that implements `ProviderUsageReader`
(`lib/features/usage/data/datasources/provider_usage_reader.dart`):

```dart
class ExampleUsageReader implements ProviderUsageReader {
  @override
  Future<ProviderUsageModel> read() async {
    // Read the provider's existing sign-in, ask for usage, return limits.
  }
}
```

- Return a `ProviderUsageModel` with one `UsageLimit` per quota window:
  `remainingPercent` (0 to 100), the window `type`, and `resetsAt` when known.
- When one provider reports the same window for several model groups, set
  `groupId` and `groupLabel` on each limit so warnings and the card keep them
  apart.
- When usage cannot be read, throw `UsageReadException` with the matching
  `UsageConnectionIssue`. `unavailable` and `appNotRunning` fall back to the
  last cached result; the others show a card that explains what to do.

Register the reader in `additionalReaders` in
`lib/features/usage/presentation/bindings/usage_binding.dart`. If people who
do not use the provider should not see a card for it, add it to
`_hiddenUntilInstalled` in `usage_data_source.dart` and throw `cliNotFound`
when it is not installed.

## 4. Draw it in the status shortcut

- **macOS** needs nothing: the menu bar uses the SVG from step 2.
- **Windows** draws marks in
  `windows/runner/windows_taskbar_status.cpp` (`PaintProviderMark`). Unknown
  ids get a generic ring; add a branch for a recognizable mark.

## Rules for readers

These keep the app's privacy promises, and a pull request that breaks one will
not be merged:

- Reuse a sign-in the user already has. Do not ask for a password, and do not
  add an account system.
- Never write a credential, token, or cookie to a cache or log file, and never
  send one anywhere except the provider it belongs to.
- Only contact the provider's own hosts, or `127.0.0.1` for a local app.
- Keep each read fast and bounded: set timeouts, and do nothing on providers
  the user turned off.

## Before opening a pull request

- Test with a real account on every platform you can, and say in the pull
  request which platforms you verified. Code for a platform you could not run
  is welcome when it is marked as untested.
- Run `flutter analyze` and `flutter test`.
- Add the provider to the README provider list and the changelog.

Provider APIs used for usage are often undocumented and change without notice.
[CodexBar](https://github.com/steipete/CodexBar) (MIT) documents how many
providers expose usage and is a good starting point; credit it in your reader
when you follow its approach.
