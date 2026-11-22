// Cases for bin/check-app-link-rules. Compiled together with
// PerSpaceLinkRouter/AppLinkRule.swift; runs without the app.

import Foundation

// (rule id, input URL, expected destination or nil for no match)
let cases: [(String, String, String?)] = [
    ("figma", "https://www.figma.com/design/AbC123xyz/My-File?node-id=1-2&t=x", "https://www.figma.com/design/AbC123xyz/My-File?node-id=1-2&t=x"),
    ("figma", "https://figma.com/board/KEY/Jam", "https://www.figma.com/board/KEY/Jam"),
    ("figma", "https://www.figma.com/proto/KEY/Flow?page-id=0%3A1", "https://www.figma.com/proto/KEY/Flow?page-id=0%3A1"),
    ("figma", "https://www.figma.com/make/KEY/Thing", "https://www.figma.com/make/KEY/Thing"),
    ("figma", "https://www.figma.com/files/team/123/recents", nil),
    ("figma", "https://www.figma.com/community/file/123", nil),
    ("figma", "https://www.figma.com/design/", nil),
    ("figma", "https://evilfigma.com/design/KEY", nil),
    ("figma", "https://www.figma.com.evil.test/design/KEY", nil),

    ("zoom", "https://us02web.zoom.us/j/81234567890?pwd=AbCdEf.1", "zoommtg://us02web.zoom.us/join?action=join&confno=81234567890&pwd=AbCdEf.1"),
    ("zoom", "https://zoom.us/j/81234567890", "zoommtg://zoom.us/join?action=join&confno=81234567890"),
    ("zoom", "https://acme.zoom.us/j/81234567890?from=addon&pwd=xyz#success", "zoommtg://acme.zoom.us/join?action=join&confno=81234567890&pwd=xyz"),
    ("zoom", "https://zoom.us/j/81234567890?xpwd=nope", "zoommtg://zoom.us/join?action=join&confno=81234567890"),
    ("zoom", "https://zoom.us/meeting/schedule", nil),
    ("zoom", "https://zoom.us.evil.test/j/123", nil),

    ("slack", "https://app.slack.com/client/T01ABCDEF/C02GHIJKL", "slack://channel?team=T01ABCDEF&id=C02GHIJKL"),
    ("slack", "https://app.slack.com/client/T01ABCDEF/D02GHIJKL/thread/D02GHIJKL-1700000000.000100", "slack://channel?team=T01ABCDEF&id=D02GHIJKL"),
    ("slack", "https://app.slack.com/client/E01ABCDEF/G02GHIJKL?cdn_fallback=1", "slack://channel?team=E01ABCDEF&id=G02GHIJKL"),
    ("slack", "https://app.slack.com/client/T01ABCDEF/unreads", nil),
    ("slack", "https://app.slack.com/client/T01ABCDEF/Cxx", nil),
    ("slack", "https://acme.slack.com/archives/C02GHIJKL/p1700000000000100", nil),

    ("discord", "https://discord.com/channels/123456789012345678/234567890123456789", "discord://discord.com/channels/123456789012345678/234567890123456789"),
    ("discord", "https://discord.com/channels/123/234/345", "discord://discord.com/channels/123/234/345"),
    ("discord", "https://ptb.discord.com/channels/@me/234567890123456789", "discord://discord.com/channels/@me/234567890123456789"),
    ("discord", "https://discordapp.com/channels/123/234", "discord://discord.com/channels/123/234"),
    ("discord", "https://discord.com/invite/abc", nil),
    ("discord", "https://discord.com/channels/123/234/../../evil", nil),

    ("spotify", "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=abc", "spotify:track:4uLU6hMCjMI75M1A2tKUQC"),
    ("spotify", "https://open.spotify.com/intl-de/album/1DFixLWuPkv3KT3TnV35m3", "spotify:album:1DFixLWuPkv3KT3TnV35m3"),
    ("spotify", "https://open.spotify.com/episode/512ojhOuo1ktJprKbVcKyQ", "spotify:episode:512ojhOuo1ktJprKbVcKyQ"),
    ("spotify", "https://open.spotify.com/user/someone", nil),
    ("spotify", "https://open.spotify.com/track/short", nil),
]

var failures = 0
for (id, input, expected) in cases {
    guard let rule = AppLinkCatalog.rules.first(where: { $0.id == id }) else {
        print("FAIL unknown rule \(id)")
        failures += 1
        continue
    }
    let actual = rule.destinationURL(for: input)?.absoluteString
    let ok = actual == expected
    if !ok { failures += 1 }
    print("\(ok ? "ok  " : "FAIL") \(id): \(input)\n       -> \(actual ?? "no match")\(ok ? "" : "  (expected \(expected ?? "no match"))")")
}

// Rules must not overlap: each case should match only its own rule.
for (id, input, _) in cases {
    for other in AppLinkCatalog.rules where other.id != id {
        if other.destinationURL(for: input) != nil {
            print("FAIL \(other.id) also matches \(input)")
            failures += 1
        }
    }
}

// Every rule starts disabled.
for rule in AppLinkCatalog.rules where rule.isEnabled {
    print("FAIL \(rule.id) is enabled by default")
    failures += 1
}

print(failures == 0 ? "\nall \(cases.count) cases passed" : "\n\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
