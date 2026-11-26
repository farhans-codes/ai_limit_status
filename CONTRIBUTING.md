# Contributing

Thank you for helping improve AI Limit Status.

## Before starting

- Search existing issues before opening a new one.
- Use a feature request for behavior changes and a bug report for reproducible
  defects.
- Do not post credentials, access tokens, private logs, or account data.
- For vulnerabilities, follow `SECURITY.md` instead of opening a public issue.

## Adding an AI provider

The app reads Codex, Claude, and Antigravity today. Support for other tools
(Cursor, Copilot, Gemini, OpenRouter, and so on) is wanted and is the easiest
way to contribute: each provider is one reader class plus a few lines of
registration. Follow [docs/adding-a-provider.md](docs/adding-a-provider.md).

Maintainers can only test the providers they have accounts for, so a provider
pull request should come from someone who uses that provider.

## Development setup

1. Fork the repository and create a focused branch from `develop`.
2. Install Flutter `3.44.2` or a compatible stable version.
3. Run:

   ```bash
   flutter pub get
   flutter analyze
   ```

4. Build and manually verify the app on every desktop platform affected by the
   change.

macOS builds require Xcode command-line tools. Windows builds require Visual
Studio with the Desktop development with C++ workload.

## Project conventions

- Keep platform access behind the existing data-source and platform-service
  boundaries.
- Keep business rules in the domain layer and UI state in GetX controllers.
- Keep the product English-only and add user-facing copy to
  `lib/core/constants/app_strings.dart`.
- Do not add Flutter localization infrastructure, ARB files, or localization
  generation steps.
- Preserve the principle that credentials are never written to app-owned cache
  or log files.
- Keep pull requests small and focused.
- Use Conventional Commit prefixes such as `feat:`, `fix:`, `docs:`,
  `refactor:`, and `chore:`.

## Pull requests

Open pull requests against `develop`, the default branch. Maintainers merge
verified changes there and delete merged feature branches.

A pull request should include:

- A concise problem statement and implementation summary.
- Platforms manually verified.
- Screenshots for visible UI changes.
- Privacy, security, or credential-handling impact.
- Documentation and changelog updates when behavior changes.

## Branches and releases

- `develop` holds work in progress. Every pull request targets it.
- `main` holds only code that is ready to ship. Maintainers open a pull request
  from `develop` into `main` when a release is due, and merge it with a merge
  commit so each `feat:` and `fix:` commit stays visible to the changelog.
- A push to `main` makes release-please open or update a Release PR with the
  next version and changelog. Merging that Release PR builds the installers and
  publishes the release, which is the only point where users get an update.
- After a release, a pull request from `main` into `develop` brings the version
  bump back.

By contributing, you agree that your contribution is licensed under the
project's MIT License.
