# Submitting Ruler to the Mac App Store

This is a second, separate distribution channel from the Developer-ID build
shipped via [GitHub Releases](https://github.com/simpel/ruler/releases) and
Homebrew (`build.sh` / `package.sh`). The two never share a signature: this
one is sandboxed and signed for the App Store; the other stays Developer-ID
signed and notarizable. Nothing here changes that pipeline.

The engineering side is done — [Ruler.entitlements](Resources/Ruler.entitlements),
[PrivacyInfo.xcprivacy](Resources/PrivacyInfo.xcprivacy) and
[package-appstore.sh](package-appstore.sh) are in the repo and the app has been
verified to run correctly fully sandboxed (see below). What's left is portal
work only an Apple Developer Program member can do.

## Why nothing had to change in the app

App Sandbox restricts file, network and hardware access — it does not restrict
window behavior. Ruler touches none of the restricted surface: no files beyond
its own `UserDefaults`, no network, no camera/mic/location. It was verified by
signing a copy with only the `app-sandbox` entitlement and running it for
real — rulers, crosshair, guides and the cursor readout all worked identically,
sandboxed by the kernel, no extra entitlements needed.

## What only you can do

All of this happens at [developer.apple.com](https://developer.apple.com/account)
and [App Store Connect](https://appstoreconnect.apple.com) — I can't act inside
your Apple account.

1. **Certificates** (Certificates, Identifiers & Profiles → Certificates → +)
   - **Apple Distribution** — signs the app itself.
   - **Mac Installer Distribution** — signs the `.pkg`.
   Keychain Access → Certificate Assistant → *Request a Certificate from a
   Certificate Authority* gives you the CSR each one asks for. Download both
   and double-click to install; confirm with:
   ```bash
   security find-identity -v -p codesigning
   ```

2. **App ID** (Identifiers → +) — register `com.github.simpel.ruler` (the
   bundle ID Ruler already ships under). No extra capabilities need enabling
   for it.

3. **Provisioning profile** (Profiles → + → Mac App Store) — tie it to that
   App ID and the Apple Distribution certificate, then download the
   `.provisionprofile` file.

4. **App Store Connect record** (My Apps → +) — name "Ruler", bundle ID from
   step 2, a SKU (anything unique, e.g. `ruler-macos`), pricing Free.
   - **Category**: Utilities
   - **Privacy Policy URL**: `https://www.joelsanden.se/ruler/privacy.html`
     (already published — Ruler collects nothing, so it's one honest paragraph)
   - **App Privacy questionnaire**: answer "Data Not Collected"
   - **Screenshots**: at least one 1280×800 (or your display's resolution)
     macOS screenshot — a shot of the rulers and menu measuring something real
     works well. Say if you'd like help composing one; I can build it the same
     way as the site illustration.
   - Support URL: the GitHub repo is fine.

5. **Build and sign** once you have all three files from steps 1–3:
   ```bash
   APPSTORE_SIGN_IDENTITY="Apple Distribution: Your Name (TEAMID)" \
   APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
   APPSTORE_PROFILE=~/Downloads/Ruler_MAS.provisionprofile \
   ./package-appstore.sh
   ```
   This produces `build/dist/Ruler-<version>-appstore.pkg`.

6. **Upload** — open the pkg with **Transporter** (free, on the Mac App
   Store) and let it deliver and validate, or from the command line:
   ```bash
   xcrun altool --upload-package build/dist/Ruler-<version>-appstore.pkg \
     --type osx --apple-id <app-apple-id> \
     --bundle-id com.github.simpel.ruler \
     --bundle-version <n> --bundle-short-version-string <version> \
     --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
   ```
   The API key comes from App Store Connect → Users and Access → Keys.
   `--upload-app` is deprecated; `--upload-package` is current.

7. **Submit for review** in App Store Connect once the build shows as
   processed. No notarization step — Apple's review replaces it for App
   Store builds.

## What I can still help with

- Composing/rendering a screenshot for the listing.
- Adjusting the entitlements if review comes back asking for something
  specific (it shouldn't — Ruler's feature set fits the sandbox as-is).
- Bumping `package-appstore.sh` for future versions once you've done steps
  1–4 once; steps 5–7 repeat per release.
