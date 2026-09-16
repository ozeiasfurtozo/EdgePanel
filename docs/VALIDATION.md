# Validation status

This document distinguishes checks completed for the local EdgePanel 0.7.2 build from release checks that remain open. The app targets Apple Silicon and macOS 14+, but the available development Mac runs macOS 26.6.2. A build on that Mac does not establish macOS 14 compatibility.

## Completed locally

- `swift test --disable-sandbox --scratch-path .build`: 10 tests passed. They cover display-coordinate clamping, settings persistence, live layout previews, widget settings, timer state, DDC target selection and parsing, and safe `.icuewidget` import.
- `./scripts/build-app.sh` completed for arm64. The app's Info.plist passed `plutil -lint`, and both the local build and installed app passed strict code-signature verification. These are ad-hoc signatures, not Developer ID signatures.
- A prior installed build kept the editor alive through a close-and-reopen cycle after a crash had been traced to sending an action to a released editor window. The app now owns that window through an `NSWindowController` with `isReleasedWhenClosed = false`.
- The XENEON video display and its `wch.cn` USB HID touch controller enumerate on the development Mac. The saved display selection resolves to the Corsair display, and the touch mapping test confines synthetic coordinates to that display's bounds.
- The selected XENEON answered DDC/CI luminance reads and writes through the bundled helper. A test changed 80 to 70 and restored 80. The final UI sends a write only after **Apply**; its value and target have been inspected in the local app.
- The editor and dashboard were captured at the XENEON's 2560 × 720 layout. Native clock, performance cards, Pixel Clock, Pixel Dashboard, independent page backgrounds, and a full-width imported timer rendered. A synthetic editor drag updated the panel during movement and persisted after release.
- A local `.icuewidget` package imported successfully. Tests reject unsafe ZIP paths and report unsupported dependencies. This does not establish compatibility with every Marketplace widget.

## Still requiring physical or release validation

- The installed app currently lacks **Input Monitoring** permission. IORegistry shows that the touch device is not seized, and the editor reports that macOS still handles touch. This explains why touches can land on the focused display. The 0.7.2 build checks this grant before attempting capture and presents a direct Settings action. Touch redirection after granting the permission has **not** been verified.
- Test taps at the center and corners, press/drag/release, rotation, scaled resolutions, disconnect during drag, sleep/wake, permission revocation, and a competing touch driver. See [HARDWARE_TESTS.md](HARDWARE_TESTS.md).
- Verify that the dashboard covers the entire XENEON menu-bar area while the menu-bar icon remains visible on the main display.
- Install a Developer ID signed and notarized DMG on a separate Apple Silicon Mac running macOS 14. Check Gatekeeper, permission persistence, touch, DDC brightness, and widget import there. The release script has not been run with signing credentials.

No claim of complete touch routing or public-release readiness is made from the automated tests alone.
