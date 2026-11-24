//
//  AppLinkRule.swift
//  PerSpaceLinkRouter
//
//  Foundation only, so bin/check-app-link-rules can compile it on its own.
//

import Foundation

/// A link that matches `pattern` opens in the app identified by
/// `bundleIdentifier` instead of the browser.
struct AppLinkRule: Codable, Equatable, Identifiable {

    /// Stable identifier. Persisted in the enabled set, so never rename one.
    let id: String
    let name: String
    let bundleIdentifier: String
    /// Matched case-insensitively against the whole URL string.
    let pattern: String
    /// Builds the URL handed to the app. `$1`...`$9` insert capture groups.
    /// A `[...]` segment is dropped when any group it references is empty,
    /// which handles optional query parameters. `\` escapes `$`, `[`, `]`
    /// and `\`. Nil passes the original URL through unchanged.
    let rewriteTemplate: String?
    var isEnabled: Bool

    /// The URL to open in the app, or nil when the rule does not apply.
    func destinationURL(for urlString: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(urlString.startIndex..., in: urlString)
        guard let match = regex.firstMatch(in: urlString, options: [], range: range) else {
            return nil
        }
        guard let template = rewriteTemplate else {
            return URL(string: urlString)
        }
        return URL(string: AppLinkRule.expand(template, match: match, in: urlString))
    }

    static func expand(_ template: String, match: NSTextCheckingResult, in source: String) -> String {
        func group(_ index: Int) -> String {
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: source) else {
                return ""
            }
            return String(source[range])
        }

        var output = ""
        var optional: String?
        var optionalIsSatisfied = true
        var characters = template.makeIterator()

        func append(_ text: String) {
            if optional != nil {
                optional! += text
            } else {
                output += text
            }
        }

        while let character = characters.next() {
            switch character {
            case "\\":
                if let escaped = characters.next() {
                    append(String(escaped))
                }
            case "$":
                guard let next = characters.next() else {
                    append("$")
                    break
                }
                if let index = next.wholeNumberValue {
                    let value = group(index)
                    if value.isEmpty {
                        optionalIsSatisfied = false
                    }
                    append(value)
                } else {
                    append("$" + String(next))
                }
            case "[" where optional == nil:
                optional = ""
                optionalIsSatisfied = true
            case "]" where optional != nil:
                if optionalIsSatisfied {
                    output += optional!
                }
                optional = nil
            default:
                append(String(character))
            }
        }
        if let unterminated = optional {
            output += "[" + unterminated
        }
        return output
    }

}

enum AppLinkCatalog {

    /// Every built-in rule: the gallery the user adds rules from. A rule
    /// takes effect only once its id is in the user's list. The ids in
    /// `seededIdentifiers` come first, then the rest by name.
    static let rules: [AppLinkRule] = [
        // Figma's open-url handler only accepts URLs whose host is exactly
        // www.figma.com (it maps figma:// onto that origin too), so the
        // rewrite only canonicalizes the host and keeps the https URL.
        AppLinkRule(
            id: "figma",
            name: "Figma",
            bundleIdentifier: "com.figma.Desktop",
            pattern: #"^https://(?:www\.)?figma\.com/((?:design|file|board|slides|proto|make)/[^/?#]+.*)$"#,
            rewriteTemplate: "https://www.figma.com/$1",
            isEnabled: false),
        // Meeting links only. Vanity subdomains (company.zoom.us) keep their
        // host so SSO-bound meetings resolve against the right account.
        AppLinkRule(
            id: "zoom",
            name: "Zoom",
            bundleIdentifier: "us.zoom.xos",
            pattern: #"^https://((?:[a-z0-9-]+\.)?zoom\.us)/j/(\d+)/?(?:\?(?:[^#]*&)?pwd=([^&#]+))?"#,
            rewriteTemplate: "zoommtg://$1/join?action=join&confno=$2[&pwd=$3]",
            isEnabled: false),
        // Channel and DM views in the web client. Team and channel ids are
        // matched case-sensitively so paths like /client/T123/unreads fall
        // through to the browser.
        AppLinkRule(
            id: "slack",
            name: "Slack",
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            pattern: #"^https://app\.slack\.com/client/(?-i:([TE][A-Z0-9]+))/(?-i:([CDG][A-Z0-9]+))(?:[/?#]|$)"#,
            rewriteTemplate: "slack://channel?team=$1&id=$2",
            isEnabled: false),
        // Discord's desktop handler accepts only the discord: scheme and
        // routes on the path, ignoring the host.
        AppLinkRule(
            id: "discord",
            name: "Discord",
            bundleIdentifier: "com.hnc.Discord",
            pattern: #"^https://(?:(?:www|ptb|canary)\.)?discord(?:app)?\.com/channels/((?:@me|\d+)(?:/\d+){0,2})/?(?:[?#]|$)"#,
            rewriteTemplate: "discord://discord.com/channels/$1",
            isEnabled: false),
        AppLinkRule(
            id: "spotify",
            name: "Spotify",
            bundleIdentifier: "com.spotify.client",
            pattern: #"^https://open\.spotify\.com/(?:intl-[a-z]{2}(?:-[a-z]+)?/)?(track|album|artist|playlist|show|episode)/([a-z0-9]{22})(?:[/?#]|$)"#,
            rewriteTemplate: "spotify:$1:$2",
            isEnabled: false),

        // The rest are gallery-only: not in a new list until added.
        AppLinkRule(
            id: "app-store",
            name: "App Store",
            bundleIdentifier: "com.apple.AppStore",
            pattern: #"^https://(apps\.apple\.com/(?:[a-z]{2}/)?(?:app|app-bundle|developer|story)/[^#]+)"#,
            rewriteTemplate: "macappstore://$1",
            isEnabled: false),
        AppLinkRule(
            id: "apple-maps",
            name: "Maps",
            bundleIdentifier: "com.apple.Maps",
            pattern: #"^https://maps\.apple\.com/"#,
            rewriteTemplate: nil,
            isEnabled: false),
        AppLinkRule(
            id: "apple-music",
            name: "Music",
            bundleIdentifier: "com.apple.Music",
            pattern: #"^https://(music\.apple\.com/[a-z]{2}/(?:album|artist|playlist|song|station|music-video)/[^#]+)"#,
            rewriteTemplate: "music://$1",
            isEnabled: false),
        AppLinkRule(
            id: "apple-podcasts",
            name: "Podcasts",
            bundleIdentifier: "com.apple.podcasts",
            pattern: #"^https://(podcasts\.apple\.com/(?:[a-z]{2}/)?podcast/[^#]+)"#,
            rewriteTemplate: "podcasts://$1",
            isEnabled: false),
        // Claude's handler accepts claude://claude.ai/chat/<uuid> and
        // /project/<uuid> with no query, and turns away chat ids whose
        // fifteenth character is 8, so those stay in the browser.
        AppLinkRule(
            id: "claude",
            name: "Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            pattern: #"^https://claude\.ai/((?:chat/(?!.{14}8)|project/)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/?$"#,
            rewriteTemplate: "claude://claude.ai/$1",
            isEnabled: false),
        // Linear resolves linear://<path> against https://linear.app. Only
        // workspace pages match, so the marketing site stays in the browser.
        AppLinkRule(
            id: "linear",
            name: "Linear",
            bundleIdentifier: "com.linear",
            pattern: #"^https://linear\.app/((?!(?:docs|developers|changelog|blog|features|integrations)/)[^/?#]+/(?:issue|project|team|view|document|initiative|cycle)/.+)$"#,
            rewriteTemplate: "linear://$1",
            isEnabled: false),
        // Meeting, chat, and channel deep links. Microsoft documents
        // msteams:/l/... as the app form of teams.microsoft.com/l/...
        AppLinkRule(
            id: "microsoft-teams",
            name: "Microsoft Teams",
            bundleIdentifier: "com.microsoft.teams2",
            pattern: #"^https://teams\.(?:microsoft|live)\.com/(l/(?:meetup-join|message|channel|chat|team|meeting|entity|call)/[^#]+)"#,
            rewriteTemplate: "msteams:/$1",
            isEnabled: false),
        // Page links carry a 32-character id. Requiring one keeps the
        // marketing and help pages in the browser.
        AppLinkRule(
            id: "notion",
            name: "Notion",
            bundleIdentifier: "notion.id",
            pattern: #"^https://(?:www\.)?notion\.so/((?:[^?#]*[/-])?[0-9a-f]{32}(?:[?#].*)?)$"#,
            rewriteTemplate: "notion://www.notion.so/$1",
            isEnabled: false),
        // steam://openurl/<url> opens the page in the Steam client. Sign-in
        // pages on steamcommunity.com are left to the browser.
        AppLinkRule(
            id: "steam",
            name: "Steam",
            bundleIdentifier: "com.valvesoftware.steam",
            pattern: #"^https://(store\.steampowered\.com/(?:app|sub|bundle)/\d+[^#]*|steamcommunity\.com/(?:sharedfiles|workshop)/[^#]+)"#,
            rewriteTemplate: "steam://openurl/https://$1",
            isEnabled: false),
        // Public usernames and their posts. Reserved first path segments
        // (invites, sticker sets, sharing) stay in the browser.
        AppLinkRule(
            id: "telegram",
            name: "Telegram",
            bundleIdentifier: "ru.keepcoder.Telegram",
            pattern: #"^https://(?:t|telegram)\.me/(?!(?:joinchat|addstickers|addemoji|addtheme|addlist|share|proxy|socks|login|setlanguage|invoice|boost|giftcode|contact)(?:[/?#]|$))([a-z][a-z0-9_]{3,31})(?:/(\d+))?/?(?:[?#]|$)"#,
            rewriteTemplate: "tg://resolve?domain=$1[&post=$2]",
            isEnabled: false),
        AppLinkRule(
            id: "testflight",
            name: "TestFlight",
            bundleIdentifier: "com.apple.TestFlight",
            pattern: #"^https://testflight\.apple\.com/(join/[a-z0-9]+)/?(?:[?#]|$)"#,
            rewriteTemplate: "itms-beta://testflight.apple.com/$1",
            isEnabled: false),
        AppLinkRule(
            id: "whatsapp",
            name: "WhatsApp",
            bundleIdentifier: "net.whatsapp.WhatsApp",
            pattern: #"^https://wa\.me/(\d+)/?(?:\?(?:[^#]*&)?text=([^&#]+))?"#,
            rewriteTemplate: "whatsapp://send?phone=$1[&text=$2]",
            isEnabled: false),
    ]

    /// The rules a new list starts with, in match order. They can be
    /// removed like any other, and added back from the gallery.
    static let seededIdentifiers = ["figma", "zoom", "slack", "discord", "spotify"]

    /// One line per built-in rule for the settings window, describing what
    /// its pattern matches.
    static let summaries: [String: String] = [
        "figma": "Design, board, slides, prototype, and Make links",
        "zoom": "Meeting links, including company subdomains",
        "slack": "Channel and DM links from app.slack.com",
        "discord": "Channel and DM links from discord.com",
        "spotify": "Track, album, artist, playlist, show, and episode links",
        "app-store": "App, developer, and story pages from apps.apple.com",
        "apple-maps": "Place, search, and directions links from maps.apple.com",
        "apple-music": "Album, artist, playlist, song, and station links",
        "apple-podcasts": "Show and episode links from podcasts.apple.com",
        "claude": "Chat and project links from claude.ai",
        "linear": "Issue, project, team, view, and document links",
        "microsoft-teams": "Meeting, chat, and channel links",
        "notion": "Page and database links from notion.so",
        "steam": "Store pages and Workshop items",
        "telegram": "Profile, channel, and post links from t.me",
        "testflight": "Beta invitation links",
        "whatsapp": "Chat links from wa.me",
    ]

    static let identifiers: Set<String> = Set(rules.map(\.id))

    private static let rulesByIdentifier: [String: AppLinkRule] =
        Dictionary(rules.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func rule(identifier: String) -> AppLinkRule? {
        return rulesByIdentifier[identifier]
    }

    /// The seeded rules, in match order.
    static var seededRules: [AppLinkRule] {
        return seededIdentifiers.compactMap(rule(identifier:))
    }

    /// Whether `rule` is the gallery's own rule. A custom rule may use a
    /// gallery id, which happens when a release adds a gallery rule under an
    /// id someone already took. That rule stays custom and takes the
    /// gallery rule's place.
    static func isBuiltIn(_ rule: AppLinkRule) -> Bool {
        guard var builtIn = rulesByIdentifier[rule.id] else {
            return false
        }
        builtIn.isEnabled = rule.isEnabled
        return builtIn == rule
    }

    /// Gallery rules not in `rules`, the user's list, sorted by name.
    static func galleryRules(notIn rules: [AppLinkRule]) -> [AppLinkRule] {
        let listed = Set(rules.map(\.id))
        return self.rules
            .filter { !listed.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// A one-line description of what a rule matches: the built-in summary,
    /// or for a custom rule the host its pattern names, or else the pattern.
    static func summary(for rule: AppLinkRule) -> String {
        if isBuiltIn(rule), let summary = summaries[rule.id] {
            return summary
        }
        if let host = host(inPattern: rule.pattern) {
            return "Links from \(host)"
        }
        return rule.pattern
    }

    /// The literal host in a pattern such as `^https://example\.com/(.+)$`,
    /// or nil when the host part uses regular expression syntax.
    static func host(inPattern pattern: String) -> String? {
        guard let schemeEnd = pattern.range(of: "://") else {
            return nil
        }
        var host = ""
        var characters = pattern[schemeEnd.upperBound...].makeIterator()
        while let character = characters.next() {
            if character == "\\" {
                guard let escaped = characters.next(), escaped == "." || escaped == "-" else {
                    return nil
                }
                host.append(escaped)
            } else if character == "/" || character == "$" {
                break
            } else if character.isLetter || character.isNumber || character == "." || character == "-" {
                host.append(character)
            } else {
                return nil
            }
        }
        // An unescaped dot means any character, but in a host it is almost
        // always meant literally, so it is shown as written.
        return host.contains(".") ? host.lowercased() : nil
    }

}
