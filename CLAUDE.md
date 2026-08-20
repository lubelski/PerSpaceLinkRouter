# OpenHere

macOS AppKit app (Swift 5 plus Objective-C ScriptingBridge wrappers) that opens
web links in a browser window in the current Space. This is a private fork of
[marcisme/OpenHere](https://github.com/marcisme/OpenHere), modernized for Apple
Silicon. `origin` is the private fork and `master` is the mainline. The
`upstream` remote points at the original repo.

## Agent Workflow

- Work in a new git worktree on a branch. Never commit directly to `master`.
- Commit and push as you go.
- Open a PR (not a draft) for the review record.
- Wait for the GitHub Actions build to pass, then merge the PR autonomously
  and delete the branch.

## Building

- The local machine has Command Line Tools only, no Xcode. CI is the build
  path.
- Every push triggers `.github/workflows/build.yml`: a Release build of
  `OpenHere.xcodeproj` on an arm64 macOS 15 runner. The workflow asserts the
  binary contains an arm64 slice and uploads the zipped app as the `OpenHere`
  artifact.
- The checkout uses `fetch-depth: 0` because the Set Version build phase
  reads git history: CFBundleShortVersionString comes from the latest tag and
  CFBundleVersion from the commit count.
- The app is ad-hoc signed with the hardened runtime and the
  `com.apple.security.automation.apple-events` entitlement. A downloaded
  artifact needs `xattr -d com.apple.quarantine OpenHere.app` before launch.
  macOS resets the Accessibility and Automation grants whenever the ad-hoc
  signature changes.
