# SpaceRouter

macOS AppKit app (Swift 5 plus Objective-C ScriptingBridge wrappers) that opens
web links in a browser window in the current Space. Derived from OpenHere by
Marc Schwieterman (GPL). `origin` is github.com/lubelski/SpaceRouter and
`master` is the mainline.

The app runs as a resident menu bar agent. `LSUIElement` is set in Info.plist,
and the Dock icon is a runtime toggle via `NSApp.setActivationPolicy`. The
settings window is built programmatically in AppDelegate; MainMenu.xib holds
only the main menu. Launch at login uses `SMAppService`, which sets the
deployment target floor at macOS 13.

## Agent Workflow

- Work in a new git worktree on a branch. Never commit directly to `master`.
- Commit and push as you go.
- Open a PR (not a draft) for the review record.
- Verify the change with a local Release build, then merge the PR autonomously
  and delete the branch.

## Building

- Build locally with Xcode. There is no CI.
- The active developer directory may point at Command Line Tools. Prefix
  commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  instead of switching it, which needs sudo.
- Release build:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project SpaceRouter.xcodeproj -target SpaceRouter -configuration Release build`
- The Set Version build phase stamps versions from git history:
  CFBundleShortVersionString from the latest tag and CFBundleVersion from the
  commit count. The placeholder values in `SpaceRouter/Info.plist` are not the
  real ones.
- The app is ad-hoc signed with the hardened runtime and the
  `com.apple.security.automation.apple-events` entitlement.
- Ad-hoc signing normally keys TCC grants to the build's cdhash, so every
  rebuild would reset the Accessibility and Automation grants. To prevent
  that, `OTHER_CODE_SIGN_FLAGS` sets an explicit designated requirement,
  `designated => identifier "com.lubelski.SpaceRouter"`, which any build of
  the app satisfies. Trade-off: any ad-hoc binary on this machine that claims
  the identifier inherits the grants. Signing with a real certificate
  (set `CODE_SIGN_IDENTITY` and remove the flag) is strictly stronger and
  supersedes this.
- If macOS prompts for Accessibility in a loop while System Settings shows
  the app as approved, the TCC entry is stale. Clear it with
  `tccutil reset Accessibility com.lubelski.SpaceRouter` and grant again.

## Releasing

- `bin/release <version>` tags, builds, signs with Developer ID, notarizes,
  staples, zips, pushes the tag, and creates the GitHub release with
  generated notes. `bin/release --check` reports what is missing.
  `--dry-run` does everything except tag and publish; `--adhoc` ad-hoc
  signs and skips notarization (Gatekeeper blocks such builds on other
  Macs, so only use it until the certificate exists).
- Tag before build is deliberate: the Set Version phase reads the newest
  tag. The script removes the tag if anything fails before publishing.
- Developer ID builds override `OTHER_CODE_SIGN_FLAGS` to `--timestamp`,
  dropping the ad-hoc designated-requirement workaround. Existing TCC grants
  still match because they were stored as
  `identifier "com.lubelski.SpaceRouter"`.
- One-time setup, in order:
  1. Apple Developer Program membership on the Apple ID signed into Xcode.
  2. Xcode > Settings > Accounts > Manage Certificates > + > Developer ID
     Application. `security find-identity -v -p codesigning` should then
     list it.
  3. An app-specific password from account.apple.com, stored for
     notarytool:
     `xcrun notarytool store-credentials SpaceRouter --apple-id <id> --team-id <TEAM>`.
  4. `gh auth login` if needed.

## TODO

- [x] Modernize the settings window UI. Done: SwiftUI `Form` with
  `.formStyle(.grouped)` hosted via `NSHostingController` in the AppKit
  lifecycle (`SettingsView.swift`), with permission/default-browser status
  rows, an activation delay stepper, and the dead `activateInNewWindow` /
  `activateInExistingWindow` defaults removed.
- [ ] Maybe: remove Safari Technology Preview support — not yet decided,
  don't do this without checking in. Touches:
  `Browsers/SafariTechnologyPreview.{h,m}`,
  `Browsers/SafariTechnologyPreviewSupport.h`,
  `SpaceRouter-Bridging-Header.h`, `BrowserManager.swift` (bundle id
  constant, `supportedBrowsers`, `supportedBrowserOrder`), `project.pbxproj`,
  `bin/generate-scripting-bridge-headers`, and the README browser list.
- [ ] Add Firefox support. Firefox has no AppleScript/ScriptingBridge
  dictionary, so the `SBApplication` approach can't work. Candidate: a
  `Process`-based `Browser` implementation that execs
  `Firefox.app/Contents/MacOS/firefox --new-window <url>` / `--new-tab <url>`,
  which remotes into the running instance (the app is not sandboxed, so
  spawning is fine; never use `open -n` — Firefox profiles lock). The
  AX-based Space detection is browser-agnostic and needs no changes. Must
  verify before shipping: which window `--new-tab` targets when windows exist
  in multiple Spaces, and whether focus stealing respects the activation
  throttle.
- [x] Retake the README screenshots. Done: `images/settings.png` (SwiftUI
  settings window) and `images/menubar.png` (menu bar with the new glyph)
  replace the OpenHere-era `select-browser.png`.
