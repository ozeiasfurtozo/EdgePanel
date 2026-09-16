# EdgePanel

EdgePanel is an independent macOS dashboard for the CORSAIR XENEON EDGE 14.5-inch display. It places a borderless, customizable panel on the XENEON and keeps the editor on your main display. It is built with SwiftUI and AppKit, works locally without an account, and stores settings in `~/Library/Application Support/EdgePanel`.

The project targets Apple Silicon and macOS 14 or later. Development and local testing have taken place on Apple Silicon with macOS 26; macOS 14 and a second Mac still need release validation. EdgePanel is not affiliated with or endorsed by CORSAIR or Elgato.

## Features

- Pages, profiles, independent page backgrounds, dark/light themes, and a live editor: moving or resizing a widget updates the XENEON before the change is saved.
- Native clock, CPU, memory, network, application launcher, timer, web, Pixel Clock, and Pixel Dashboard widgets. The 2 × 2 application widget shows the selected app's icon with its name underneath, without a card or heading. Native widgets have per-instance appearance controls.
- Single-touch click and drag redirection to the explicitly selected XENEON display, with orientation controls and a calibration overlay.
- Physical brightness control through the bundled DDC/CI helper, with an explicit **Apply** action.
- Partial `.icuewidget` import and runtime support, including CPU and RAM sensors. Each imported instance has its own WKWebView and storage. Network access is disabled until the user allows a requested HTTPS domain.
- A menu-bar icon for opening the editor, switching profiles and pages, and quitting. Optional launch at login.

No Marketplace artwork or widget package is bundled. Pixel Clock and Pixel Dashboard are original widgets inspired by the [Pixel Clock](https://marketplace.elgato.com/product/pixel-clock-7268e1d1-43f5-4ae8-ac8d-2c59090a0a80) and [PIXEL//DASH XL](https://marketplace.elgato.com/product/pixeldash-xl-ce18bdb8-e63c-4fa0-95df-44ad530b1ccc) concepts. The native clock and performance widgets take visual inspiration from [Smoke Clock](https://marketplace.elgato.com/product/smoke-clock-c8bd2410-3619-49c4-8e1c-e5678c142269) and [Performance Grapher](https://marketplace.elgato.com/product/performance-grapher-48ceb9c8-0244-42e6-a7f1-21c9090a6d6d), without bundling their assets.

## Build and run

Install Xcode or the Apple Command Line Tools, accept the Xcode license, then run:

```sh
./scripts/build-app.sh
open dist/EdgePanel.app
```

The script builds an arm64 app, bundles the `m1ddc` helper, and ad-hoc signs the local build. Use one stable app path, and quit any running EdgePanel before replacing it. If macOS asks for permissions again after an update, grant them to the copy you actually launch. Developer ID signing and notarization are required for a public download; the local build is not notarized.

To run the tests:

```sh
swift test --disable-sandbox --scratch-path .build
```

On first launch, select the XENEON in the editor's **Display** section. Add widgets, drag them in the preview, and use the lower-right handle to resize. Select a widget for its controls, or click an empty area of the preview to edit the page name and background. The UI follows the Mac's English or Portuguese language setting; this documentation uses the English labels.

## Touch setup

The display needs both a video connection and its USB touch connection. Select the XENEON explicitly and turn on **Enable touch**. macOS must grant EdgePanel **Input Monitoring** to capture the touch controller and **Accessibility** to post the redirected click and drag events. These permissions are managed in **System Settings → Privacy & Security**.

If the editor says **“macOS is still handling touch”**, open **Input Monitoring** from its warning, enable EdgePanel, return to the app, and click **Check again**. Until the controller is captured, touching the XENEON may still click on the display currently in focus. If the grant does not take effect, quit and reopen the installed app. Use **Calibrate touch** to check the center and corners, and adjust **Swap axes**, **Invert horizontal**, or **Invert vertical** if needed.

Run only one touch driver for this controller at a time. EdgePanel targets the saved Corsair display identity and never substitutes another monitor if that display disappears. With a captured controller but missing Accessibility permission, it discards touch reports rather than posting them elsewhere. Only one XENEON and one contact are supported; multitouch gestures are not implemented. See the [hardware test checklist](docs/HARDWARE_TESTS.md) for scenarios that still require physical validation.

## Brightness

The **Hardware brightness** control reads the selected XENEON through DDC/CI. Moving the slider previews a value; **Apply** sends it to the display. The video cable or dock must pass DDC/CI commands. If the display is absent, ambiguous, or does not answer DDC, the control reports an error and does not target another monitor. The helper is based on MIT-licensed [m1ddc](https://github.com/waydabber/m1ddc); DisplayBuddy is not required.

## iCUE widget compatibility

Use **iCUE library → Import .icuewidget**, or open an `.icuewidget` file in Finder with **Open With → EdgePanel**. The importer checks the ZIP structure, manifest, required files, checksums, paths, symlinks, and size limits before installing a package. Unsupported dependencies are shown before activation.

| Capability | Status |
| --- | --- |
| Local HTML, CSS, JavaScript, and assets | Supported in a separate WKWebView per widget instance |
| iCUE initialization, IDs, configurable properties, and callbacks | Partial implementation |
| Color, text, switch, slider, list, tabs, and sensor selection | Supported controls |
| Sensors Data Provider 1.0 | Real Mac CPU and RAM usage only |
| Translations and per-instance local storage | Supported subset |
| Network requests | Only requested HTTPS domains individually enabled by the user |
| GPU, temperature, fan, and firmware sensors | Unsupported; values are never fabricated |
| Media, Stream Deck, Windows notifications, binary plugins, full iCUE profiles | Unsupported |

iCUE's official widget runtime uses Chromium, while EdgePanel uses WKWebView. A package that imports successfully can therefore render or behave differently. Imported JavaScript has no bridge to the shell, arbitrary files, or touch control. Imported packages retain their authors' licenses and are not part of this repository.

## Contributing and release status

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a change. [docs/VALIDATION.md](docs/VALIDATION.md) records what has been checked locally and what remains unverified. In particular, physical touch after granting Input Monitoring, macOS 14, and installation on a second Mac still require testing.

`scripts/release-dmg.sh` prepares a Developer ID signed, hardened, notarized DMG when a publisher supplies signing credentials. Do not put credentials in the repository. The release script has not been exercised with a Developer ID certificate; a public release should complete the [hardware and clean-install checklist](docs/HARDWARE_TESTS.md) first.

EdgePanel is available under the [MIT License](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md) for the touch reference project and bundled DDC helper.
