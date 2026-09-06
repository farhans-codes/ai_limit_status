# Windows taskbar and Claude regression checks

Run these checks on Windows 10 or 11 with a build containing the taskbar fix.
The changes apply only to Windows; macOS behavior is unchanged.

## Claude detection and authentication

1. With Claude signed in through VS Code but no standalone `claude` on PATH,
   click **Check again**. A standard VS Code/VS Code Insiders extension install
   should no longer be reported as missing. Authentication still requires a
   Claude subscription OAuth credential, not just a running IDE/API-key session.
2. Check existing file-backed sign-in: `%USERPROFILE%\.claude\.credentials.json`
   remains authoritative when Claude has not enabled its secure store. If
   `CLAUDE_CODE_FORCE_WINDOWS_CREDMAN=1` or Claude's `tengu_windows_credman` feature
   is enabled, the matching secure store takes priority over a leftover file.
3. On a Claude install that migrated to Windows Credential Manager, verify usage
   appears without installing another CLI. Both single-value and chunked secure
   credentials are supported. The app reads only the current user's exact Claude
   target, never enumerates other credentials or writes secure credentials back.
4. Sign out/in through Claude itself while AI Limit Status stays open. The next
   allowed refresh should reread the current credential, without a ten-minute
   stale-token delay. A successful usage snapshot still refreshes every two minutes.
5. If using a custom Claude config profile, launch both apps with the same
   `CLAUDE_CONFIG_DIR` / `CLAUDE_SECURESTORAGE_CONFIG_DIR`. Verify the same account
   appears; other profiles should not be scanned. An empty secure-storage override
   selects the default profile. Unicode profile paths should hash as NFC UTF-8.

Do not share token values or credential contents. Missing/expired credentials,
WSL-only sign-ins, or a third-party/API-key session cannot guarantee subscription
usage. The existing browser connection remains the fallback.

The format-only check uses synthetic data and no Flutter test framework or OS
credential access. Run it manually from the repository root:

```sh
dart --enable-asserts scripts/check_windows_claude_credentials.dart
```

## Display and click targets

1. Show both providers. Percentages should include `%` (including `0%` and
   `100%` when those values occur). A disconnected provider should show `—`,
   not a made-up percentage. Both icons and numbers should share a vertical
   center and remain legible at 100%, 125%, 150%, and 200% display scaling.
2. Click an icon, its number, the gap between providers, and the empty padding
   around them. Each click inside the indicator rectangle should toggle the
   details window once, without launching the taskbar application underneath.
3. Repeat with only one provider enabled. Its hit target should follow the
   narrower indicator rather than occupying the old two-provider width.

## Taskbar interactions

1. Open and dismiss the system tray overflow, then click another taskbar button.
   The indicator should remain visible and clickable without waiting for the
   next usage refresh.
2. Leave the details window open through several one-second positioning checks
   and a usage refresh. The indicator should not steal focus or repeatedly
   hide/show either window.
3. Right-click the indicator and use **Open details**. It should open the same
   popup as a left-click, anchored above the taskbar.
4. Restart Windows Explorer from Task Manager. The indicator should recreate
   itself and retain its click behavior.
5. Enable taskbar auto-hide, reveal/hide the taskbar, and restore the setting.
   The indicator should follow taskbar visibility without leaving stale icons.

## Implementation notes

- GDI drawing is flushed before the DIB's alpha bytes are assigned. The entire
  transparent rectangle retains nonzero alpha so it can receive mouse input.
- Unchanged bitmap content does not imply unchanged stacking order. Foreground
  and window-order events schedule an order check; the existing timer is a
  fallback. Order is repaired only when the taskbar has moved above the overlay,
  without activating the overlay or repainting the bitmap.
- The raw percentage is preserved and both providers use the same DPI-scaled
  icon and text sizes, including three-digit values.

References: [GDI bitmap synchronization](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-createdibsection),
[layered-window hit testing](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features),
[window ordering](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos),
[Claude's bundled CLI](https://code.claude.com/docs/en/vs-code#vs-code-extension-vs-claude-code-cli),
[Bun's Windows credential target format](https://github.com/oven-sh/bun/blob/0d0b28b906727a232caf9993a0c05e6ac70548bd/src/jsc/bindings/SecretsWindows.cpp).
