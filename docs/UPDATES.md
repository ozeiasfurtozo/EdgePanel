# In-app updates

EdgePanel 0.8.4 introduces Sparkle 2.10.0. **Check for Updates…** is available from the menu-bar icon. Sparkle checks the HTTPS appcast at `https://raw.githubusercontent.com/ozeiasfurtozo/EdgePanel/main/appcast.xml`, verifies the EdDSA signature on each download, and installs an accepted update over the existing app. The private signing key is stored in the publisher's macOS Keychain under the `edgepanel` account; the public key is in `Resources/Info.plist`.

The appcast in this repository is initially empty. It must be committed to the `main` branch before checks can succeed. A new release will not appear in the app until the signed DMG is uploaded to GitHub Releases **and** the generated `appcast.xml` is committed to `main`. Users of 0.8.3 or earlier need one manual install of 0.8.4 or newer because those builds did not contain Sparkle. Users can copy the new app over `/Applications/EdgePanel.app`; they do not need to delete the old app or erase settings.

## Local builds and privacy permissions

As [Apple explains](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements), ad-hoc signatures identify a single build by its code hash. After a code change, macOS may treat the rebuilt app as a new identity and ask again for Input Monitoring and Accessibility. `build-app.sh` now requires a stable signing identity by default. Specify an existing Apple Development certificate with `EDGE_LOCAL_SIGN_IDENTITY`, or place its SHA-1 fingerprint in the ignored `.edgepanel-signing-identity` file. The explicit `EDGE_ALLOW_ADHOC_SIGN=1` option remains for disposable test builds.

Use `security find-identity -v -p codesigning` to list available fingerprints. Keep the same fingerprint for subsequent local builds. The ignored file contains one fingerprint and no private key.

The touch controller checks existing permissions on launch and wake without opening authorization prompts. It requests access when the user explicitly turns on **Enable touch**. If access is missing later, use the buttons in the editor to open the relevant macOS Privacy & Security page and select **Check again** after granting it.

An Apple Development identity is suitable for local development and does not require creating a new key or changing the Keychain's trust settings when one already exists. The private key stays in the Keychain; the ignored local file contains only the certificate fingerprint. Switching from the existing ad-hoc app to this identity requires granting macOS privacy permissions once for the newly signed app. Switching later to a Developer ID release may require one more grant because the signing identity changes again.

## Preparing a release

1. Increment `CFBundleShortVersionString` and monotonically increment `CFBundleVersion` in `Resources/Info.plist`. Keep the same bundle identifier and Sparkle public key.
2. On the publisher's Mac, confirm that `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account edgepanel -p` matches `SUPublicEDKey`. The release script checks this automatically. Back up the **private** key securely; never commit or share it. A new publisher must import the existing key, not generate a replacement without planning key rotation.
3. Configure a Developer ID Application signing identity and a `notarytool` Keychain profile. Set `EDGE_SIGN_IDENTITY` and `EDGE_NOTARY_PROFILE`, then run `./scripts/release-dmg.sh`. The script builds the app, signs Sparkle's nested helpers and the app with Hardened Runtime, notarizes and staples `EdgePanel-VERSION.dmg`, and signs a new appcast entry with the `edgepanel` key.
4. Create the matching GitHub tag `vVERSION` and upload `.build/release-output/EdgePanel-VERSION.dmg` to that tag's release. Only after the asset is available, commit the generated `appcast.xml` to `main`. The appcast points to that exact release asset URL.
5. On a Mac with the previous release installed in `/Applications`, choose **Check for Updates…**. Verify the version, download, installation, relaunch, settings, and permissions. Repeat on the minimum supported macOS 14 and another Apple Silicon Mac before announcing support.

The GitHub release and feed publication are deliberate manual steps. `release-dmg.sh` does not upload or publish them. Signing and notarization have not yet been exercised on this project because the current development Mac has no Developer ID identity. The local `build-app.sh` output uses an Apple Development identity when one is configured; it is intended for development, not as a public update archive.
