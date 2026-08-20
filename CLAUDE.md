# SpaceRouter

macOS AppKit app (Swift 5 plus Objective-C ScriptingBridge wrappers) that opens
web links in a browser window in the current Space. Derived from OpenHere by
Marc Schwieterman (GPL). `origin` is the private repo and `master` is the
mainline.

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
  `com.apple.security.automation.apple-events` entitlement. macOS resets the
  Accessibility and Automation grants whenever the ad-hoc signature changes.
