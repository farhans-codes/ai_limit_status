# Contributing

Thank you for helping improve AI Limit Status.

## Before starting

- Search existing issues before opening a new one.
- Use a feature request for behavior changes and a bug report for reproducible
  defects.
- Do not post credentials, access tokens, private logs, or account data.
- For vulnerabilities, follow `SECURITY.md` instead of opening a public issue.

## Development setup

1. Fork the repository and create a focused branch from `main`.
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

A pull request should include:

- A concise problem statement and implementation summary.
- Platforms manually verified.
- Screenshots for visible UI changes.
- Privacy, security, or credential-handling impact.
- Documentation and changelog updates when behavior changes.

By contributing, you agree that your contribution is licensed under the
project's MIT License.
