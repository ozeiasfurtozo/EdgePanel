# Contributing to EdgePanel

Thank you for helping improve EdgePanel. The project is an independent macOS app for the CORSAIR XENEON EDGE. Contributions should keep the app usable without an account or server and should preserve the distinction between tested behavior and hardware assumptions.

## Set up a development build

Use an Apple Silicon Mac with macOS 14 or later and Xcode or the Apple Command Line Tools. Accept the Xcode license, then run:

```sh
./scripts/build-app.sh
open dist/EdgePanel.app
```

Use one stable app path for manual tests. Quit a running copy before replacing it; macOS grants Input Monitoring and Accessibility to the installed app identity. The local script ad-hoc signs the app. It does not make a public release build.

Run the tests with:

```sh
swift test --disable-sandbox --scratch-path .build
```

## Propose a change

- Describe the observed problem, the intended behavior, and the macOS and display configuration used to reproduce it. Attach a minimal `.icuewidget` only if its license permits redistribution; remove personal data first.
- Keep changes focused. Preserve the selected-display binding: a missing or ambiguous XENEON must never cause a synthetic click on another display.
- Add a focused test for data parsing, persistence, or coordinate logic when it protects behavior. Physical touch, DDC, window stacking, permissions, and WebKit rendering also require manual verification; record which checks you actually performed.
- Keep user-facing strings in English and Portuguese. Keep project documentation in English.
- Do not add signing certificates, API keys, exported personal settings, downloaded Marketplace artwork, or third-party widget packages to the repository.

The [hardware checklist](docs/HARDWARE_TESTS.md) covers touch, display layout, widgets, imports, brightness, and release installation. The [validation record](docs/VALIDATION.md) states the current evidence boundary.

## Third-party code and licensing

EdgePanel uses the MIT License. The bundled `ThirdParty/m1ddc` source retains its own MIT license and upstream attribution. The touch implementation was developed with reference to the MIT-licensed Xeneon Touch project. Preserve [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) when distributing the app. Explain the license and provenance of any new dependency or asset in a contribution.
