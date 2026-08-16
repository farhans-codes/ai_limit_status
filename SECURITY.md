# Security policy

## Supported versions

Security fixes are provided for the latest published release line.

| Version | Supported |
| --- | --- |
| 0.3.x | Yes |
| 0.2.x and earlier | No |

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability or credential leak.
Use GitHub's private vulnerability-reporting flow:

https://github.com/farhans-codes/ai_limit_status/security/advisories/new

Include:

- The affected version and operating system.
- Reproduction steps or a minimal proof of concept.
- Expected impact.
- Whether provider credentials or personal data may be exposed.
- Any suggested mitigation.

Do not include real access tokens, credentials, or private account data. Use
clearly fake test values.

The maintainer will acknowledge a complete report as soon as practical,
investigate it privately, and coordinate disclosure after a fix is available.

## Security boundaries

- Codex authentication is managed by the locally installed Codex CLI.
- Claude authentication is managed by Claude Code. AI Limit Status reads the
  existing OAuth credential only to request usage from Anthropic and does not
  persist that token in app-owned storage.
- Cached usage files are not intended to contain secrets.
- Release artifacts should be downloaded only from this repository's GitHub
  Releases page and verified with the published SHA256 checksums.
