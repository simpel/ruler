# Continuous Integration & Mac App Store Delivery

Distanser uses **GitHub Actions** (`.github/workflows/appstore.yml`) to automatically build, sign, package, and deliver builds to **App Store Connect** on every commit pushed to `main` (or on demand via `workflow_dispatch`).

---

## How It Works

1. **Trigger**: Pushing to `main` or manually running the workflow from the GitHub Actions tab.
2. **Environment**: Apple Silicon `macos-15` runner with the latest Xcode.
3. **Versioning**: Sets `CFBundleVersion` dynamically to `$(( 100 + github.run_number ))` so every build uploaded to App Store Connect has a guaranteed unique, monotonically increasing build number exceeding previous submissions (build 7).
4. **Signing**: Imports your **Apple Distribution** certificate and **Mac Installer Distribution** ("3rd Party Mac Developer Installer") certificate into an isolated temporary runner keychain.
5. **Provisioning**: Uses the Mac App Store provisioning profile (`Resources/Distanser_MAS.provisionprofile` or the `BUILD_PROVISION_PROFILE_BASE64` secret).
6. **Packaging**: Runs `package-appstore.sh` to compile a universal binary (`arm64` + `x86_64`), codesign the sandboxed `Distanser.app`, and package it into a signed `.pkg` installer via `productbuild`.
7. **Artifacting**: Saves `Distanser-<version>-appstore.pkg` as an artifact on the GitHub run for debugging or local archiving.
8. **Upload**: Uses your App Store Connect API Key to upload the `.pkg` directly to App Store Connect via `xcrun altool --upload-package`.

---

## Required GitHub Repository Secrets

Navigate to your GitHub repository:
**Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Add the following secrets:

| Secret Name | Required? | Description | Example / Format |
| :--- | :--- | :--- | :--- |
| `APP_STORE_CONNECT_KEY_ID` | **Yes** | Key ID of your App Store Connect API Key | `2X9R4HXF34` (10 chars) |
| `APP_STORE_CONNECT_ISSUER_ID` | **Yes** | Issuer ID from App Store Connect | `57246542-96fe-1a63-e053-0824d011072a` (UUID) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | **Yes** | Full text content of the `.p8` key file | `-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----` |
| `BUILD_CERTIFICATE_BASE64` | **Yes** | Base64-encoded `.p12` containing your **Apple Distribution** cert (and optionally **Mac Installer Distribution** cert) | Raw base64 string |
| `P12_PASSWORD` | **Yes** | Password used when exporting the `.p12` certificate | Plain text string |
| `INSTALLER_CERTIFICATE_BASE64` | *Optional* | Base64-encoded `.p12` if you exported the installer cert separately | Raw base64 string |
| `INSTALLER_P12_PASSWORD` | *Optional* | Password for separate installer `.p12` (defaults to `P12_PASSWORD`) | Plain text string |
| `BUILD_PROVISION_PROFILE_BASE64` | *Optional* | Base64-encoded `.provisionprofile` (falls back to `Resources/Distanser_MAS.provisionprofile`) | Raw base64 string |

---

## Generating Credentials (Step-by-Step)

### 1. App Store Connect API Key (`.p8`)

1. Open [App Store Connect: Users and Access](https://appstoreconnect.apple.com/access/integrations/api).
2. Select the **Integrations** (or **Keys**) tab → **App Store Connect API**.
3. Click **+** (Generate API Key).
   - **Name**: `GitHub Actions MAS Delivery`
   - **Access**: **App Manager** or **Admin** (required for uploading binaries).
4. Note the **Issuer ID** at the top → copy into `APP_STORE_CONNECT_ISSUER_ID`.
5. Note the **Key ID** in the table → copy into `APP_STORE_CONNECT_KEY_ID`.
6. Click **Download API Key** (`AuthKey_<KeyID>.p8`).
   > [!IMPORTANT]
   > Apple only permits downloading this `.p8` file once.
7. Copy the entire file contents to your clipboard:
   ```bash
   cat AuthKey_*.p8 | pbcopy
   ```
8. Paste into `APP_STORE_CONNECT_PRIVATE_KEY`.

---

### 2. Apple Distribution & Mac Installer Certificates (`.p12`)

Submitting a macOS `.pkg` requires two certificates:
- **Apple Distribution**: signs the sandboxed `.app` bundle.
- **Mac Installer Distribution** (or *3rd Party Mac Developer Installer*): signs the `.pkg` installer with `productbuild`.

#### Option A: Export Both Together (Recommended)
1. Open **Keychain Access** on your Mac.
2. Select the **login** keychain and click **My Certificates**.
3. Hold `Cmd` and select both:
   - `Apple Distribution: Joel Sanden (D4F66LSYSF)`
   - `3rd Party Mac Developer Installer: Joel Sanden (D4F66LSYSF)`
4. Right-click → **Export 2 items...**.
5. Save as `mas_distribution.p12`.
6. Enter an export password → save this password in GitHub secret `P12_PASSWORD`.
7. Encode to base64 and copy to clipboard:
   ```bash
   base64 -i mas_distribution.p12 | pbcopy
   ```
8. Paste into `BUILD_CERTIFICATE_BASE64`.

#### Option B: Export Separately
If you prefer exporting them individually:
1. Export `Apple Distribution` as `app_distribution.p12` → base64 → `BUILD_CERTIFICATE_BASE64`.
2. Export `3rd Party Mac Developer Installer` as `installer_distribution.p12` → base64 → `INSTALLER_CERTIFICATE_BASE64`.
3. Set `P12_PASSWORD` and optionally `INSTALLER_P12_PASSWORD`.

---

### 3. Mac App Store Provisioning Profile (`.provisionprofile`)

The repo already includes `Resources/Distanser_MAS.provisionprofile`. If you ever regenerate or renew the profile:

1. Open [Apple Developer: Profiles](https://developer.apple.com/account/resources/profiles/list).
2. Click **+** → Select **Mac App Store** under Distribution.
3. App ID: `se.joelsanden.ruler`.
4. Certificate: Select your Apple Distribution certificate.
5. Download the `.provisionprofile` file.
6. Either replace `Resources/Distanser_MAS.provisionprofile` directly in git, or encode it to base64:
   ```bash
   base64 -i Distanser_MAS.provisionprofile | pbcopy
   ```
   and save into secret `BUILD_PROVISION_PROFILE_BASE64`.

---

## Verifying the Automated Build

1. Push a change to `main` or trigger manually:
   - Go to your GitHub repository → **Actions** tab.
   - Select **Deploy to App Store Connect**.
   - Click **Run workflow** on `main`.
2. Monitor build execution:
   - The `.pkg` will be uploaded to the run artifacts for inspection.
   - `altool` streams the upload status to App Store Connect.
3. Check [App Store Connect: Apps](https://appstoreconnect.apple.com/apps) → **Distanser**:
   - The build will appear under **macOS Builds** with a status of "Processing" for ~5–10 minutes.
   - Once processed, it can be attached to your version release or tested via TestFlight for macOS.
