# SpaceRouter

`SpaceRouter` opens web links in the current Space. It requires macOS 13 or
later and builds natively for Apple Silicon.

Do you use Spaces/Mission Control on your Mac?

Do you get frustrated when you open a web link, and you get switched to a
different Space or the link silently opens in a new browser tab in a different
Space?

Me too.

## How It Works

`SpaceRouter` is set as the default web browser, so it receives any links that
are opened. When links are opened, `SpaceRouter` uses the Accessibility APIs to
see if there is a browser window in the current Space. If there isn't, it will
open a new browser window. The link is then opened in a new tab in your chosen
browser. Browser interaction uses the AppleScript scripting bridge.

## Installation

Build `SpaceRouter.xcodeproj` with Xcode. The app is ad-hoc signed with a
stable designated requirement, so the Accessibility and Automation grants
survive rebuilds. See CLAUDE.md for the trade-off.

* Move `SpaceRouter.app` into your `Applications` folder
* Launch `SpaceRouter`
* Grant Accessibility access in `System Settings` > `Privacy & Security` >
  `Accessibility`
* Launch `SpaceRouter` again
* Select the browser you want links opened with
* Click the `Set SpaceRouter as Default Browser` button
* Open a link to verify it opens in your desired browser. The first open
  triggers an Automation permission prompt ("SpaceRouter wants access to
  control ..."); allow it so `SpaceRouter` can drive the browser

## Features

* Open links in the current Space
* Prevent window activation when opening several links in a row
* Menu bar icon with access to settings
* Optional hidden Dock icon
* Optional start at login

## Usage

You should now be able to open links as you do normally, and they should always
open in the current Space.

`SpaceRouter` stays running as a menu bar agent. To change which browser it
forwards links to, or to toggle the Dock icon and start at login, click the
menu bar icon and choose `Settings…`.

![Menu bar icon](/images/menubar.png)

![Settings window](/images/settings.png)

If you lose track of the window and the menu bar icon, launch `SpaceRouter`
again. Reopening a running instance always shows the settings window.

If you decide `SpaceRouter` isn't for you, you can restore your preferred
default browser by selecting it in `System Settings` > `Desktop & Dock` >
`Default web browser`.

## Supported Browsers

Current versions of the following should work.

* Safari
* Safari Technology Preview
* Chrome

## Privacy

`SpaceRouter` does not and will never log anything about the URLs that it
opens.

You can walk through the entire execution path from where the link open event
is handled (`handleGetURLEvent` in
[AppDelegate.swift](/SpaceRouter/AppDelegate.swift)), to the general browser
handling (`openURL` in
[BrowserManager.swift](/SpaceRouter/BrowserManager.swift)), to the
browser-specific handling for [Chrome](/SpaceRouter/Browsers/Chrome.m),
[Safari](/SpaceRouter/Browsers/Safari.m) and [Safari Technology
Preview](/SpaceRouter/Browsers/SafariTechnologyPreview.m).

`SpaceRouter` uses no third party frameworks.

## License

`SpaceRouter` is released under the [GPL](/LICENSE) license. It is derived
from OpenHere by Marc Schwieterman.

## Attribution

AppleScript, Mission Control, and Spaces are trademarks of Apple Inc.,
registered in the U.S. and other countries.
