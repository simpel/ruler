# Contributing to Distanser

Thank you for contributing to Distanser! To maintain a clear history and automate releases reliably, this project follows **Semantic Versioning** and **Conventional Commits** (Semantic Release).

---

## Commit Message Convention

All commit messages (and PR titles when squash-merging) must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

### Types & Release Impact

The commit type determines how the change is classified and which semantic version bump it triggers:

| Type | Description | Release Impact | SemVer Bump |
| :--- | :--- | :--- | :--- |
| `feat` | A new user-facing feature or enhancement | New release | **MINOR** (`1.5.0` → `1.6.0`) |
| `fix` | A bug fix | New release | **PATCH** (`1.5.0` → `1.5.1`) |
| `perf` | Code change that improves performance | New release (or patch) | **PATCH** |
| `docs` | Documentation-only changes (README, guides) | No release | None |
| `style` | Code formatting, whitespace, commas (no logic change) | No release | None |
| `refactor` | Code restructuring that neither fixes bugs nor adds features | No release | None |
| `test` | Adding or updating unit tests / CI test scripts | No release | None |
| `chore` | Maintenance tasks, repository hygiene, dependencies | No release | None |
| `ci` | Changes to CI/CD workflows and actions | No release | None |
| `build` | Build system, packaging scripts, or compilation flags | No release | None |

### Breaking Changes

Any commit that introduces breaking changes must indicate it by appending an exclamation point (`!`) before the colon, or by including a `BREAKING CHANGE:` footer. This triggers a **MAJOR** version bump (`1.5.0` → `2.0.0`).

#### Examples:

- **Minor feature**:
  ```git
  feat(guides): add magnetic snap to nearest ruler tick
  ```
- **Patch bugfix**:
  ```git
  fix(overlay): prevent crosshair flicker on secondary display
  ```
- **Chore / maintenance**:
  ```git
  chore(deps): update packaging script for universal binary output
  ```
- **Breaking change (with `!`)**:
  ```git
  feat(settings)!: rework stored geometry key format for multi-monitor setups
  ```
- **Breaking change (with footer)**:
  ```git
  feat(ruler): require macOS 14 Sonoma or later

  BREAKING CHANGE: Dropped support for macOS 13 Ventura due to new AppKit window APIs.
  ```

---

## Release Process

Distanser uses Semantic Release principles to publish releases:

### Automated CI/CD (App Store Connect & Releases)

When committing or merging to `main`, the CD pipeline (`.github/workflows/appstore.yml`) automatically:
1. Analyzes commit messages since the last release tag.
2. Computes the next version following Conventional Commits (major for breaking changes, minor for `feat`, patch for fixes/others).
3. Updates `Resources/Info.plist` with the new `CFBundleShortVersionString` and dynamic `CFBundleVersion`.
4. Tags and commits the release back to `main` with `[skip ci]`.
5. Packages and submits the build to App Store Connect.

### Manual Version Bumping

You can also bump the version locally using the helper script:
```bash
# Auto-detect based on conventional commits
./Tools/bump-version.sh --write

# Or specify bump level
./Tools/bump-version.sh --bump patch --write
./Tools/bump-version.sh --bump minor --write
./Tools/bump-version.sh --bump 1.7.0 --write
```

3. **Commit the version bump**:
   ```bash
   git add Resources/Info.plist
   git commit -m "chore(release): bump to v1.6.0"
   ```

4. **Tag the release**:
   Create an annotated or lightweight tag formatted as `vMAJOR.MINOR.PATCH`:
   ```bash
   git tag v1.6.0
   ```

5. **Push tag to trigger GitHub Actions**:
   ```bash
   git push origin main
   git push origin v1.6.0
   ```

6. **Automated Publishing**:
   - `.github/workflows/release.yml` triggers on `v*` tags.
   - Compiles universal arm64 + x86_64 binaries.
   - Packages `Distanser-<version>.dmg` and `.zip`.
   - Creates the GitHub Release with download assets.
   - Updates the Homebrew formula in `simpel/homebrew-tap`.
