# PerSpaceLinkRouter

`PerSpaceLinkRouter` opens web links in the current Space, on the display under
your cursor. It requires macOS 13 or later and builds natively for Apple Silicon.

Do you use Spaces/Mission Control on your Mac?

Do you get frustrated when you open a web link, and you get switched to a
different Space or the link silently opens in a new browser tab in a different
Space?

Me too.

## How It Works

`PerSpaceLinkRouter` is set as the default web browser, so it receives any links that
are opened. When a link is opened, `PerSpaceLinkRouter` finds the display under the
mouse cursor and uses the Accessibility APIs to see if there is a browser window
in that display's current Space. If there is, the link opens in a new tab of the
frontmost such window. If there isn't, it opens a new browser window centered on
that display. Browser interaction uses the AppleScript scripting bridge.

## Installation

Download `PerSpaceLinkRouter-<version>.zip` from the
[latest release](https://github.com/lubelski/PerSpaceLinkRouter/releases/latest),
or build `PerSpaceLinkRouter.xcodeproj` with Xcode. Local builds are ad-hoc signed
with a stable designated requirement, so the Accessibility and Automation
grants survive rebuilds. See CLAUDE.md for the trade-off.

* Move `PerSpaceLinkRouter.app` into your `Applications` folder
* Launch `PerSpaceLinkRouter`
* Grant Accessibility access in `System Settings` > `Privacy & Security` >
  `Accessibility`
* Launch `PerSpaceLinkRouter` again
* Select the browser you want links opened with
* Click the `Set PerSpaceLinkRouter as Default Browser` button
* Open a link to verify it opens in your desired browser. The first open
  triggers an Automation permission prompt ("PerSpaceLinkRouter wants access to
  control ..."); allow it so `PerSpaceLinkRouter` can drive the browser

## Features

* Open links in the current Space
* Prevent window activation when opening several links in a row
* Menu bar icon with access to settings
* Optional hidden Dock icon
* Optional start at login
* Release builds update themselves

## Usage

You should now be able to open links as you do normally, and they should always
open in the current Space.

`PerSpaceLinkRouter` stays running as a menu bar agent. To change which browser it
forwards links to, click the menu bar icon and choose a browser from `Open Links
With`. A checkmark identifies the saved selection.

`Settings…` opens a window with a sidebar of four pages:

* General: the browser to open links with, setting the default browser, the
  activation delay, the Dock icon, and start at login
* App Links: the rules that open links in apps instead of the browser
  (see below)
* Permissions: the Accessibility and Automation grants, what each is for, and
  a button to System Settings when one is missing
* Updates: automatic updates, the version, and `Check for Updates…`

The window reopens on the page you last had open.

![Menu bar icon](/images/menubar.png)

![Settings window](/images/settings.png)

If you lose track of the window and the menu bar icon, launch `PerSpaceLinkRouter`
again. Reopening a running instance always shows the settings window.

If you decide `PerSpaceLinkRouter` isn't for you, you can restore your preferred
default browser by selecting it in `System Settings` > `Desktop & Dock` >
`Default web browser`.

## App Links

`PerSpaceLinkRouter` can open some links in their native app instead of the
browser. The `App Links` page of `Settings…` lists every rule in match order;
the first enabled rule that matches a link wins. All of the built-in rules
are off by default:

* Figma: design, FigJam board, slides, prototype, and Make links
* Zoom: meeting links (`zoom.us/j/…`, including company subdomains)
* Slack: channel and DM links from the web client (`app.slack.com/client/…`)
* Discord: channel and DM links (`discord.com/channels/…`)
* Spotify: track, album, artist, playlist, show, and episode links

On the page you can:

* Turn each rule on or off, and drag rules to change the match order. A rule
  whose app isn't installed is grayed out and can't be turned on.
* Add a custom rule with `+`: pick the app, give a name, a link pattern (a
  regular expression matched against the whole link, case-insensitively),
  and optionally what to send the app instead (`$1` to `$9` insert the parts
  the pattern captured; leave it empty to pass the link through unchanged).
* `Edit…` or remove (`−`) a custom rule. Built-in rules can't be edited;
  `Duplicate` makes an editable custom copy of any rule.
* `Test a link`: paste a link to see which rule catches it and the URL the
  app would receive, or that it goes to the browser. Nothing is opened.
* `Open Config File` opens the rules as a JSON file (see below).

Hold Option (⌥) while opening a link to send it to the browser anyway. A link
that an app hands back to the browser itself, such as Figma's `Open in
Browser`, also goes to the browser instead of looping back into the app.

Known limitation: the per-Space routing only applies to browsers. An app link
opens wherever the app puts it, which may be a window in another Space. macOS
has no public API for moving another app's windows between Spaces.

### The config file

The rules live in a JSON file, which the Settings window and a text editor
edit alike:

```
~/Library/Application Support/PerSpaceLinkRouter/app-links.json
```

The app is not sandboxed, so this is the Application Support folder in your
home folder. The file is created the first time you change something on the
`App Links` page or click `Open Config File`; until then the app uses the
built-in rules and the toggles you set in earlier versions. Once it exists,
the file is the source of truth. The app watches it and picks up every saved
change without a restart. If a saved file has an error, the app keeps using
the last good rules and the `App Links` page shows what is wrong.

### For agents and scripts

To change the app link rules, edit the config file and then validate it.

Find the file. It is normally the path above; `path` prints it:

```
/Applications/PerSpaceLinkRouter.app/Contents/MacOS/PerSpaceLinkRouter app-links path
```

The schema:

```json
{
  "version": 1,
  "order": ["my-rule", "slack", "figma", "zoom", "discord", "spotify"],
  "enabled": ["my-rule", "slack"],
  "rules": [
    {
      "id": "my-rule",
      "name": "Example",
      "bundleIdentifier": "com.example.app",
      "pattern": "^https://example\\.com/(.+)$",
      "rewrite": "example://$1"
    }
  ]
}
```

* `version`: always `1`.
* `rules`: custom rules only. The built-in rules (`figma`, `zoom`, `slack`,
  `discord`, `spotify`) live in the app and can't be changed here; copy one
  under a new id instead.
  * `id`: lowercase letters, digits, and hyphens; unique, and not a built-in
    id. Other keys refer to the rule by it.
  * `name`: shown in the Settings window.
  * `bundleIdentifier`: the app that opens the link, such as
    `com.example.app`. `osascript -e 'id of app "AppName"'` prints an
    installed app's identifier.
  * `pattern`: a regular expression (ICU syntax, as `NSRegularExpression`
    reads it) matched case-insensitively against the whole link. Escape
    backslashes for JSON: `\\.` in the file is `\.` in the pattern.
  * `rewrite`: the URL handed to the app. `$1` to `$9` insert capture
    groups, and `$0` the whole match. A `[...]` part is dropped when a group
    it uses is empty. `\` escapes `$`, `[`, `]`, and `\`. Leave the key out,
    or set it to `null` or `""`, to pass the link through unchanged.
* `order`: rule ids in match order, built-in and custom. The first enabled
  rule that matches wins. Ids not listed go at the end, so a built-in rule
  added by a later release appears there. Unknown ids are ignored.
* `enabled`: the ids of the rules that are on. Unknown ids are ignored.

The app reloads the file as soon as it is saved. After editing, run `check`;
it exits non-zero and lists each error (which rule, which field) when the
file is invalid:

```
/Applications/PerSpaceLinkRouter.app/Contents/MacOS/PerSpaceLinkRouter app-links check
```

The other commands:

```
PerSpaceLinkRouter app-links list
PerSpaceLinkRouter app-links test "https://example.com/some/link"
PerSpaceLinkRouter app-links check
PerSpaceLinkRouter app-links path
```

* `list`: one line per rule, in match order: on or off, id, name, built-in
  or custom, and whether the app is installed.
* `test <url>`: the id of the rule that catches the link and the URL the app
  would receive (`my-rule → example://some/link`), or `browser`. When a rule
  matches but is off or its app is missing, a `note:` line says so. Exits 0
  either way. It opens nothing.
* `check`: exits 0 with a one-line summary when the file is valid or absent,
  and 1 with the errors when it isn't.
* `path`: prints the config file's path.

`list` and `test` exit 1 when the file is invalid; fix it first. Usage errors
exit 2. The commands only read: they never write the file or start the app's
window, menu bar icon, or updater, and they work while the app is running.
Set `PERSPACELINKROUTER_APP_LINKS_FILE` to a path to use a different config
file, for trying one out or for tests. The running app also reads that
variable, but only when it is set in the app's own environment.

## Updates

A build from the releases page updates itself with
[Sparkle](https://sparkle-project.org). It checks the feed on GitHub about once
a day, downloads a newer build, verifies its signature, and relaunches into it.
The `Updates` page of `Settings…` has a switch that turns this off, and the
menu has `Check for Updates…`.

A build you make yourself with Xcode has no feed and never updates itself.

## Supported Browsers

Current versions of the following should work.

* Safari
* Safari Technology Preview
* Chrome

## Privacy

`PerSpaceLinkRouter` does not and will never log anything about the URLs that it
opens.

You can walk through the entire execution path from where the link open event
is handled (`handleGetURLEvent` in
[AppDelegate.swift](/PerSpaceLinkRouter/AppDelegate.swift)), to the general browser
handling (`openURL` in
[BrowserManager.swift](/PerSpaceLinkRouter/BrowserManager.swift)), to the app
link rules ([AppLinkRouter.swift](/PerSpaceLinkRouter/AppLinkRouter.swift),
[AppLinkConfig.swift](/PerSpaceLinkRouter/AppLinkConfig.swift), and
[AppLinkRule.swift](/PerSpaceLinkRouter/AppLinkRule.swift)), to the
browser-specific handling for [Chrome](/PerSpaceLinkRouter/Browsers/Chrome.m),
[Safari](/PerSpaceLinkRouter/Browsers/Safari.m) and [Safari Technology
Preview](/PerSpaceLinkRouter/Browsers/SafariTechnologyPreview.m).

Sparkle is the only third party framework. A release build uses it to fetch
the update feed and new builds from GitHub, and it sends nothing about you or
your links.

## License

`PerSpaceLinkRouter` is released under the [GPL](/LICENSE) license. It is derived
from OpenHere by Marc Schwieterman.

## Attribution

AppleScript, Mission Control, and Spaces are trademarks of Apple Inc.,
registered in the U.S. and other countries.
