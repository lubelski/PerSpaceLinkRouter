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
