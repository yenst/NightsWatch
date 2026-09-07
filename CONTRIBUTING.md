# Development

NightsWatch is an Omarchy Quickshell plugin. Keep the plugin manifest and QML entry points at the repository root so `omarchy plugin add` can install it directly.

## Files

- `Panel.qml`: bar entry point and keyboard popup.
- `Content.qml`: list, search, detail view, and interactions.
- `Icon.qml`: icons from the installed Material Design Nerd Font library.
- `Service.qml`: polling and short-lived helper processes.
- `scripts/ports.py`: listener discovery and identity-checked SIGTERM.

## Local installation

```sh
python3 scripts/install.py
omarchy plugin enable jihmy.nightswatch --section right
```

The development installer validates and copies the runtime files into `~/.config/omarchy/plugins/jihmy.nightswatch`. It can update that plugin, leaves unrelated files alone, and does not enable it automatically. Do not symlink the checkout into the plugin directory: Omarchy's validator rejects symlinks.

Rerun the installer after edits. If Quickshell retains an older component, run `omarchy restart shell` to clear the cache. Never edit packaged files under `/usr/share/omarchy/`.

For an existing installation cloned from GitHub, prefer `omarchy plugin update jihmy.nightswatch` over mixing local development files into the managed checkout.

## Checks

```sh
omarchy plugin validate .
python3 -m unittest discover -s tests -v
python3 scripts/test_ui.py
```

Backend integration tests create and stop only their own disposable processes. They require Linux pidfd support; listener discovery also needs local socket access. A restricted sandbox can skip listener integration, so run it with normal user permissions before a release.

The UI harness requires the local Omarchy shell, Quickshell, and its QML imports. It renders the real UI with example data, exercises filtering, navigation, immediate stopping and its guards, and captures short/long command states in a temporary directory. It never signals real processes. Keep screenshots in `docs/screenshots` free of personal command lines or other desktop content.

Also check the installed panel: placement, mouse hover, keyboard navigation, scrolling, theme changes, and timestamp updates. Keep the top-level list compact and use Omarchy's shared font and color tokens.
