# NightsWatch design verification

final result: passed

Native Omarchy Quickshell plugin, verified 2026-09-07. Design target: `design/approved.png`, with the user's subsequent request to reduce typography to match Framework Fans. This is a desktop plugin, so verification used actual QML rendering and the running Omarchy panel rather than a browser prototype.

## Changes after comparison

- Initial title and port numerals were too large beside fanctrl. Replaced custom pixel sizes with native `Style.font` tokens: title 14, ports 16, project/body 12, secondary 11 and caption 10 at the default font scale. Reduced panel content width from 480 to 400 logical pixels, rows from 64 to 48, and surrounding spacing accordingly.
- Fixed partially clipped first row when reopening by returning the list to its beginning. Disabled ListView automatic current-item positioning; unchanged scan results no longer reset the model.
- Replaced filled action/group icons with the installed outline glyph variants. The stop icon appears on row hover or keyboard selection without a visible label.
- Made long process details scroll within the fitted popup height. Process disappearance has an explicit state.
- Retained time-only refresh indication in the header, filter field, grouped rows, and Apps/System navigation. No bottom update or keyboard-hint footer.

## Evidence

`design/implementation.png`, `design/detail.png`, and `design/long-command.png` are actual QML captures using controlled fixture data. The implementation is 808 pixels wide at 2x render density, including its border. The original generated mock includes surrounding canvas and uses different density; comparison accounted for those differences. The later explicit fanctrl font-size request supersedes the original mock's oversized typography.

The final installed panel was also opened on the user's Wayland desktop after clearing Quickshell's cached components. Verified compact typography, unclipped initial row, timestamp, real inventory, group counts, and bounded list height. Theme colors, typography, and glyphs follow the installed Omarchy theme. There are no raster assets in the functional UI; the images here are documentation only.

The runnable UI harness exercises filter matches/no matches, selection, detail navigation, immediate stop and ownership guards, group navigation, and a listener disappearing during inspection. Backend tests cover actual discovery and SIGTERM of disposable owned listeners, refusal of changed process identity, foreign ownership, IPv6 scopes, multiple owners, duplicate bindings, and failed scan reporting. Plugin manifest validation and native Wayland component loading passed.

## Remaining limitations

- Apps classification uses an exact Hyprland window PID match, as in the inspiration. Separate helper processes can appear under Your Processes.
- One row represents a protocol/address/port/owner binding. The same port number can appear more than once for distinct bindings; details distinguish them.
- Minor glyph shapes and the destructive accent intentionally come from the current native icon font/theme rather than the image model's custom drawings.

No unresolved blocking visual findings.

## Detail and stop-action revision

User requested no confirmation and no kill-button hover fill. The action now immediately calls the existing identity-checked stop helper. All icon buttons use tight glyph bounds for visual centering; the kill action has a transparent background at rest and on hover.

Created `design/detail-concept.png` and implemented its layout with native font sizing. Back, copy-address, and stop actions sit in a fixed toolbar above the detail scroller. Metadata precedes a bounded command area with its own scroll and copy action. The generated concept's excessive blank canvas is not part of the implementation. `design/detail.png` and `design/long-command.png` verify compact and long-command states. Current theme colors follow the desktop, including theme changes during verification.

Repeated live port numbers were inspected: 3300 and 3400 each have separate IPv4/IPv6 bindings for the same PID; 1716 has TCP and UDP bindings. The backend intentionally retains those distinct sockets. No grouping behavior was requested or changed.

UI workflow tests pass with immediate-stop, null-target, ownership and busy guards. Native manifest validation passed and updated code was installed.
