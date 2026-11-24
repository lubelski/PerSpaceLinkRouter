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

    ("app-store", "https://apps.apple.com/us/app/xcode/id497799835?mt=12", "macappstore://apps.apple.com/us/app/xcode/id497799835?mt=12"),
    ("app-store", "https://apps.apple.com/app/id497799835", "macappstore://apps.apple.com/app/id497799835"),
    ("app-store", "https://apps.apple.com/us/developer/apple/id284417353#see-all", "macappstore://apps.apple.com/us/developer/apple/id284417353"),
    ("app-store", "https://apps.apple.com/", nil),
    ("app-store", "https://apps.apple.com.evil.test/us/app/x/id1", nil),

    ("apple-maps", "https://maps.apple.com/?q=Coffee&ll=37.33,-122.03", "https://maps.apple.com/?q=Coffee&ll=37.33,-122.03"),
    ("apple-maps", "https://maps.apple.com/place?place-id=I1234ABCD", "https://maps.apple.com/place?place-id=I1234ABCD"),
    ("apple-maps", "https://maps.apple.com.evil.test/?q=x", nil),
    ("apple-maps", "https://www.apple.com/maps/", nil),

    ("apple-music", "https://music.apple.com/us/album/some-album/1440857781?i=1440857786", "music://music.apple.com/us/album/some-album/1440857781?i=1440857786"),
    ("apple-music", "https://music.apple.com/gb/playlist/a-list/pl.abc123", "music://music.apple.com/gb/playlist/a-list/pl.abc123"),
    ("apple-music", "https://music.apple.com/us/browse", nil),
    ("apple-music", "https://music.apple.com/subscribe", nil),

    ("apple-podcasts", "https://podcasts.apple.com/us/podcast/a-show/id1200361736?i=1000600000000", "podcasts://podcasts.apple.com/us/podcast/a-show/id1200361736?i=1000600000000"),
    ("apple-podcasts", "https://podcasts.apple.com/podcast/id1200361736", "podcasts://podcasts.apple.com/podcast/id1200361736"),
    ("apple-podcasts", "https://podcasts.apple.com/us/browse", nil),

    ("claude", "https://claude.ai/chat/01234567-89ab-4def-8123-456789abcdef", "claude://claude.ai/chat/01234567-89ab-4def-8123-456789abcdef"),
    ("claude", "https://claude.ai/project/01234567-89ab-8def-8123-456789abcdef/", "claude://claude.ai/project/01234567-89ab-8def-8123-456789abcdef"),
    ("claude", "https://claude.ai/chat/01234567-89ab-8def-8123-456789abcdef", nil),
    ("claude", "https://claude.ai/chat/01234567-89ab-4def-8123-456789abcdef?q=hello", nil),
    ("claude", "https://claude.ai/new", nil),
    ("claude", "https://claude.ai/settings/profile", nil),
    ("claude", "https://claude.ai.evil.test/chat/01234567-89ab-4def-8123-456789abcdef", nil),

    ("linear", "https://linear.app/acme/issue/ENG-123/fix-the-thing", "linear://acme/issue/ENG-123/fix-the-thing"),
    ("linear", "https://linear.app/acme/project/launch-abc123/overview?tab=updates", "linear://acme/project/launch-abc123/overview?tab=updates"),
    ("linear", "https://linear.app/acme/team/ENG/active", "linear://acme/team/ENG/active"),
    ("linear", "https://linear.app/docs/team/issues", nil),
    ("linear", "https://linear.app/changelog", nil),
    ("linear", "https://linear.app/login", nil),
    ("linear", "https://linear.app/acme/settings/account", nil),

    ("microsoft-teams", "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d", "msteams:/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d"),
    ("microsoft-teams", "https://teams.live.com/l/chat/0/0?users=someone", "msteams:/l/chat/0/0?users=someone"),
    ("microsoft-teams", "https://teams.microsoft.com/v2/", nil),
    ("microsoft-teams", "https://teams.microsoft.com/dl/launcher/launcher.html?url=x", nil),

    ("notion", "https://www.notion.so/acme/Roadmap-0123456789abcdef0123456789abcdef?pvs=4", "notion://www.notion.so/acme/Roadmap-0123456789abcdef0123456789abcdef?pvs=4"),
    ("notion", "https://notion.so/0123456789abcdef0123456789abcdef", "notion://www.notion.so/0123456789abcdef0123456789abcdef"),
    ("notion", "https://www.notion.so/acme/0123456789abcdef0123456789abcdef?v=fedcba9876543210fedcba9876543210#block", "notion://www.notion.so/acme/0123456789abcdef0123456789abcdef?v=fedcba9876543210fedcba9876543210#block"),
    ("notion", "https://www.notion.so/product", nil),
    ("notion", "https://www.notion.so/help/guides", nil),
    ("notion", "https://acme.notion.site/Page-0123456789abcdef0123456789abcdef", nil),
    ("notion", "https://www.notion.so/login?redirect=0123456789abcdef0123456789abcdef", nil),

    ("steam", "https://store.steampowered.com/app/620/Portal_2/", "steam://openurl/https://store.steampowered.com/app/620/Portal_2/"),
    ("steam", "https://steamcommunity.com/sharedfiles/filedetails/?id=123456", "steam://openurl/https://steamcommunity.com/sharedfiles/filedetails/?id=123456"),
    ("steam", "https://steamcommunity.com/openid/login?openid.mode=checkid_setup", nil),
    ("steam", "https://store.steampowered.com/login/", nil),
    ("steam", "https://store.steampowered.com.evil.test/app/620", nil),

    ("telegram", "https://t.me/durov", "tg://resolve?domain=durov"),
    ("telegram", "https://t.me/telegram/123", "tg://resolve?domain=telegram&post=123"),
    ("telegram", "https://telegram.me/some_channel/", "tg://resolve?domain=some_channel"),
    ("telegram", "https://t.me/joinchat/AbCdEf", nil),
    ("telegram", "https://t.me/share/url?url=https://example.com", nil),
    ("telegram", "https://t.me/+AbCdEf123", nil),
    ("telegram", "https://t.me/s/telegram", nil),
    ("telegram", "https://t.me/addstickers", nil),

    ("testflight", "https://testflight.apple.com/join/AbCd1234", "itms-beta://testflight.apple.com/join/AbCd1234"),
    ("testflight", "https://testflight.apple.com/join/AbCd1234?utm=x", "itms-beta://testflight.apple.com/join/AbCd1234"),
    ("testflight", "https://testflight.apple.com/", nil),
    ("testflight", "https://testflight.apple.com/join/../x", nil),

    ("whatsapp", "https://wa.me/15551234567", "whatsapp://send?phone=15551234567"),
    ("whatsapp", "https://wa.me/15551234567?text=Hello%20there", "whatsapp://send?phone=15551234567&text=Hello%20there"),
    ("whatsapp", "https://wa.me/qr/ABCDEF", nil),
    ("whatsapp", "https://wa.me.evil.test/15551234567", nil),
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

// The seeded ids name catalog rules, and the catalog ids are unique.
for id in AppLinkCatalog.seededIdentifiers where AppLinkCatalog.rule(identifier: id) == nil {
    print("FAIL seeded id \(id) is not in the catalog")
    failures += 1
}
if Set(AppLinkCatalog.rules.map(\.id)).count != AppLinkCatalog.rules.count {
    print("FAIL catalog ids are not unique")
    failures += 1
}

// Every rule has cases above.
for rule in AppLinkCatalog.rules where !cases.contains(where: { $0.0 == rule.id && $0.2 != nil }) {
    print("FAIL \(rule.id) has no matching case")
    failures += 1
}

// Every rule starts disabled.
for rule in AppLinkCatalog.rules where rule.isEnabled {
    print("FAIL \(rule.id) is enabled by default")
    failures += 1
}

print(failures == 0 ? "\nall \(cases.count) cases passed" : "\n\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
