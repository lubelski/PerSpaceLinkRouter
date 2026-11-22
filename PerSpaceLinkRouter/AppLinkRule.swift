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

    /// Built-in rules, all disabled until the user turns them on. Order
    /// matters: the first enabled, installed, matching rule wins.
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
    ]

    /// The catalog with the user's enabled set applied.
    static func rules(enabledIdentifiers: Set<String>) -> [AppLinkRule] {
        return rules.map { rule in
            var rule = rule
            rule.isEnabled = enabledIdentifiers.contains(rule.id)
            return rule
        }
    }

}
