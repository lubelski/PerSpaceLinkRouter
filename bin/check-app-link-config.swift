// Cases for bin/check-app-link-config. Compiled together with
// PerSpaceLinkRouter/AppLinkRule.swift, AppLinkConfig.swift, and
// AppLinkConfigStore.swift; runs without the app. File cases use the
// temporary folder passed as the first argument, never the real config.

import Foundation

var passed = 0
var failures = 0

func expect(_ condition: @autoclosure () -> Bool, _ label: String, _ detail: @autoclosure () -> String = "") {
    if condition() {
        passed += 1
    } else {
        failures += 1
        let extra = detail()
        print("FAIL \(label)\(extra.isEmpty ? "" : "\n       \(extra)")")
    }
}

func section(_ title: String) {
    print("-- \(title)")
}

func data(_ json: String) -> Data {
    return Data(json.utf8)
}

func parse(_ json: String) -> (AppLinkConfig?, [AppLinkConfigIssue]) {
    do {
        return (try AppLinkConfigParser.parse(data(json)), [])
    } catch let error as AppLinkConfigError {
        return (nil, error.issues)
    } catch {
        return (nil, [AppLinkConfigIssue("unexpected \(error)")])
    }
}

/// Expects the JSON to be rejected with an issue matching every given part.
func expectIssue(_ json: String, _ label: String, ruleIndex: Int? = nil, ruleIdentifier: String? = nil, field: String? = nil, containing text: String) {
    let (config, issues) = parse(json)
    let found = issues.contains { issue in
        (ruleIndex == nil || issue.ruleIndex == ruleIndex)
            && (ruleIdentifier == nil || issue.ruleIdentifier == ruleIdentifier)
            && (field == nil || issue.field == field)
            && issue.description.contains(text)
    }
    expect(config == nil && found, "rejects: \(label)", "issues: \(issues.map(\.description))")
}

func expectValid(_ json: String, _ label: String) -> AppLinkConfig? {
    let (config, issues) = parse(json)
    expect(config != nil, "accepts: \(label)", "issues: \(issues.map(\.description))")
    return config
}

func ids(_ rules: [AppLinkRule]) -> [String] {
    return rules.map(\.id)
}

func enabledIDs(_ rules: [AppLinkRule]) -> [String] {
    return rules.filter(\.isEnabled).map(\.id)
}

let builtInOrder = ["figma", "zoom", "slack", "discord", "spotify"]

let example = #"""
{
  "version": 2,
  "order": ["my-rule", "slack", "figma", "linear"],
  "enabled": ["my-rule", "slack", "linear"],
  "rules": [
    { "id": "my-rule", "name": "Example", "bundleIdentifier": "com.example.app",
      "pattern": "^https://example\\.com/(.+)$", "rewrite": "example://$1" }
  ]
}
"""#

let validRuleFields = #""name": "Example", "bundleIdentifier": "com.example.app", "pattern": "^https://example\\.com/(.+)$""#

func rule(_ id: String, pattern: String = #"^https://example\.com/(.+)$"#, rewrite: String? = "example://$1",
          bundle: String = "com.example.app", enabled: Bool = false) -> AppLinkRule {
    return AppLinkRule(id: id, name: id.capitalized, bundleIdentifier: bundle, pattern: pattern,
                       rewriteTemplate: rewrite, isEnabled: enabled)
}

// MARK: - Catalog

section("catalog")
expect(AppLinkCatalog.seededIdentifiers == builtInOrder, "seeded rules")
expect(Array(ids(AppLinkCatalog.rules).prefix(builtInOrder.count)) == builtInOrder, "the catalog starts with the seeded rules")
expect(ids(AppLinkCatalog.seededRules) == builtInOrder, "every seeded id is in the catalog")
expect(AppLinkCatalog.rules.count > builtInOrder.count, "the gallery has more than the seeded rules")
expect(Set(ids(AppLinkCatalog.rules)).count == AppLinkCatalog.rules.count, "catalog ids are unique")
for builtIn in AppLinkCatalog.rules {
    expect(AppLinkConfig.isValidIdentifier(builtIn.id), "built-in id \(builtIn.id) is a valid id")
    expect(AppLinkCatalog.summaries[builtIn.id] != nil, "built-in \(builtIn.id) has a summary")
    expect(AppLinkRuleValidator.issues(for: builtIn).isEmpty, "built-in \(builtIn.id) passes rule validation",
           "\(AppLinkRuleValidator.issues(for: builtIn))")
    expect(AppLinkCatalog.isBuiltIn(builtIn), "isBuiltIn(\(builtIn.id))")
    var enabledBuiltIn = builtIn
    enabledBuiltIn.isEnabled = true
    expect(AppLinkCatalog.isBuiltIn(enabledBuiltIn), "isBuiltIn(\(builtIn.id)) when on")
}
expect(!AppLinkCatalog.isBuiltIn(rule("my-rule")), "custom id is not built-in")
expect(!AppLinkCatalog.isBuiltIn(rule("notion")), "a custom rule with a gallery id is not built-in")

// The gallery is the catalog minus the list, by name.
let galleryForSeeded = AppLinkCatalog.galleryRules(notIn: AppLinkCatalog.seededRules)
expect(Set(ids(galleryForSeeded)) == AppLinkCatalog.identifiers.subtracting(builtInOrder), "gallery leaves out the rules in the list")
expect(galleryForSeeded.map(\.name) == galleryForSeeded.map(\.name).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
       "gallery is sorted by name")
expect(Set(ids(AppLinkCatalog.galleryRules(notIn: []))) == AppLinkCatalog.identifiers, "an empty list puts every rule in the gallery")
expect(!ids(AppLinkCatalog.galleryRules(notIn: [rule("notion")])).contains("notion"), "a custom rule with a gallery id hides that gallery rule")

// MARK: - Parsing the example

section("parsing")
if let config = expectValid(example, "the documented example") {
    let rules = config.resolvedRules()
    expect(ids(rules) == ["my-rule", "slack", "figma", "linear"], "example order", "\(ids(rules))")
    expect(enabledIDs(rules) == ["my-rule", "slack", "linear"], "example enabled", "\(enabledIDs(rules))")
    expect(config.customRules.count == 1, "example has one custom rule")
    let custom = config.customRules[0]
    expect(custom.pattern == #"^https://example\.com/(.+)$"#, "JSON escapes decode in pattern", custom.pattern)
    expect(custom.rewriteTemplate == "example://$1", "rewrite read")
    expect(custom.destinationURL(for: "https://example.com/a/b")?.absoluteString == "example://a/b", "custom rule rewrites")
    expect(custom.destinationURL(for: "HTTPS://EXAMPLE.COM/x") != nil, "custom pattern is case-insensitive")
}

_ = expectValid(#"{"version": 1}"#, "only a version")
_ = expectValid(#"{"version": 2}"#, "only a version, 2")
_ = expectValid(#"{"version": 2.0, "order": ["figma"], "enabled": [], "rules": []}"#, "version 2.0")
_ = expectValid(#"{"version": 1.0, "order": [], "enabled": [], "rules": []}"#, "version 1.0 and empty arrays")
_ = expectValid(#"{"version": 1, "order": null, "enabled": null, "rules": null}"#, "null arrays")

// rewrite absent, null, or empty all pass the link through
for (label, field) in [("absent", ""), ("null", #", "rewrite": null"#), ("empty", #", "rewrite": """#)] {
    let json = #"{"version": 1, "rules": [{"id": "pass", "name": "Pass", "bundleIdentifier": "com.example.app", "pattern": "^https://example\\.com/"\#(field)}]}"#
    if let config = expectValid(json, "rewrite \(label)") {
        let custom = config.customRules.first
        expect(custom?.rewriteTemplate == nil, "rewrite \(label) is nil")
        expect(custom?.destinationURL(for: "https://example.com/x?y=1")?.absoluteString == "https://example.com/x?y=1",
               "rewrite \(label) passes the link through")
    }
}

// MARK: - Ordering

section("ordering")
func resolved(order: [String], enabled: [String] = [], custom: [AppLinkRule] = []) -> [AppLinkRule] {
    return AppLinkConfig(order: order, enabled: enabled, customRules: custom).resolvedRules()
}
expect(ids(resolved(order: [])).isEmpty, "an empty order is an empty list")
expect(ids(resolved(order: ["spotify", "zoom"])) == ["spotify", "zoom"],
       "built-ins missing from order are not in use", "\(ids(resolved(order: ["spotify", "zoom"])))")
expect(ids(resolved(order: ["zoom", "notion"])) == ["zoom", "notion"], "a gallery rule named in order is in use")
expect(ids(resolved(order: ["nope", "zoom", "also-nope"])) == ["zoom"], "unknown ids in order are ignored")
expect(ids(resolved(order: ["zoom", "figma", "zoom"])) == ["zoom", "figma"], "a repeated id counts at its first place")
expect(enabledIDs(resolved(order: ["zoom"], enabled: ["ghost", "zoom"])) == ["zoom"], "unknown ids in enabled are ignored")
expect(enabledIDs(resolved(order: ["zoom"], enabled: ["zoom", "slack"])) == ["zoom"], "enabling a rule that is not in order does nothing")
expect(ids(resolved(order: ["slack"], custom: [rule("b"), rule("a")])) == ["slack", "b", "a"],
       "custom rules missing from order follow in file order",
       "\(ids(resolved(order: ["slack"], custom: [rule("b"), rule("a")])))")

// A custom rule may take a gallery rule's id, and then replaces it.
let shadow = resolved(order: ["notion", "zoom"], enabled: ["notion"], custom: [rule("notion")])
expect(shadow.first?.bundleIdentifier == "com.example.app" && shadow.first?.isEnabled == true, "a custom rule with a gallery id replaces the gallery rule")
let shadowConfig = AppLinkConfig(rules: shadow)
expect(ids(shadowConfig.customRules) == ["notion"], "the replacing custom rule is written back as custom")
expect(AppLinkConfig(rules: resolved(order: ["notion", "zoom"])).customRules.isEmpty, "gallery rules are not written as custom rules")

// Version 1 kept the five rules of its day in use whatever order said.
func resolvedV1(_ body: String) -> [AppLinkRule] {
    return (try? AppLinkConfigParser.parse(data(#"{"version": 1, \#(body)}"#)))?.resolvedRules() ?? []
}
expect(ids(resolvedV1(#""order": []"#)) == builtInOrder, "version 1: an empty order is the five seeded rules")
expect(ids(resolvedV1(#""order": ["spotify", "zoom"], "enabled": ["zoom"]"#)) == ["spotify", "zoom", "figma", "slack", "discord"],
       "version 1: seeded rules missing from order go at the end")
expect(enabledIDs(resolvedV1(#""order": ["spotify", "zoom"], "enabled": ["zoom"]"#)) == ["zoom"], "version 1: enabled carries over")
expect(ids(resolvedV1(#""order": ["slack"], "rules": [{"id": "b", \#(validRuleFields)}, {"id": "a", \#(validRuleFields)}]"#))
        == ["slack", "b", "a", "figma", "zoom", "discord", "spotify"],
       "version 1: custom rules missing from order come before the missing seeded rules")
expect(!ids(resolvedV1(#""order": []"#)).contains("notion"), "version 1: gallery rules added later are not put in use")
let upgraded = try! AppLinkConfigParser.parse(data(#"{"version": 1, "order": ["zoom"], "enabled": ["zoom"]}"#))
let upgradedText = String(decoding: AppLinkConfigSerializer.data(for: upgraded), as: UTF8.self)
expect(upgradedText.contains("\"version\": 2") && upgradedText.contains(#""order": ["zoom", "figma", "slack", "discord", "spotify"]"#),
       "a version 1 file is written back as version 2 with its full list", upgradedText)
expect(ids(resolved(order: ["zoom"])) == ["zoom"] && (try? AppLinkConfigParser.parse(data(#"{"version": 2, "order": ["zoom"]}"#)))?.order == ["zoom"],
       "version 2: order is the whole list")

// Removing a seeded rule and adding a gallery rule both survive a write.
var listed = AppLinkConfig.fallback(enabledIdentifiers: ["slack"]).resolvedRules()
listed.removeAll { $0.id == "figma" }
var added = AppLinkCatalog.rule(identifier: "linear")!
added.isEnabled = true
listed.append(added)
let relisted = try! AppLinkConfigParser.parse(AppLinkConfigSerializer.data(for: AppLinkConfig(rules: listed))).resolvedRules()
expect(ids(relisted) == ["zoom", "slack", "discord", "spotify", "linear"], "a removed seeded rule stays removed, an added gallery rule stays", "\(ids(relisted))")
expect(enabledIDs(relisted) == ["slack", "linear"], "and the enabled set is kept")
expect(ids(AppLinkCatalog.galleryRules(notIn: relisted)).contains("figma"), "a removed seeded rule is back in the gallery")
expect(ids(resolved(order: ["a", "zoom", "b"], custom: [rule("b"), rule("a")])).prefix(3) == ["a", "zoom", "b"],
       "custom and built-in rules interleave as ordered")
let resolvedEnabled = resolved(order: [], enabled: ["a"], custom: [rule("a", enabled: false), rule("b", enabled: true)])
expect(enabledIDs(resolvedEnabled) == ["a"], "enabled list, not the rule's own flag, decides", "\(enabledIDs(resolvedEnabled))")

let fallback = AppLinkConfig.fallback(enabledIdentifiers: ["slack", "ghost"])
expect(fallback.order == builtInOrder, "fallback order is the seeded rules")
expect(fallback.enabled == ["slack"], "fallback carries the UserDefaults set, minus unknown ids")
expect(fallback.customRules.isEmpty, "fallback has no custom rules")
expect(enabledIDs(AppLinkConfig.fallback(enabledIdentifiers: []).resolvedRules()).isEmpty, "fallback with nothing on")

// AppLinkConfig(rules:) is the inverse of resolvedRules.
let original = AppLinkConfig(order: ["a", "slack", "figma", "zoom", "discord", "spotify"], enabled: ["a", "zoom"],
                             customRules: [rule("a")])
let rebuilt = AppLinkConfig(rules: original.resolvedRules())
expect(rebuilt.resolvedRules() == original.resolvedRules(), "config from rules resolves the same")
expect(rebuilt.enabled == ["a", "zoom"], "config from rules keeps enabled in match order")
expect(rebuilt.customRules.allSatisfy { !$0.isEnabled }, "stored custom rules carry no enabled flag")
var moved = original.resolvedRules()
moved.insert(moved.remove(at: 0), at: 2)
expect(AppLinkConfig(rules: moved).order == ["slack", "figma", "a", "zoom", "discord", "spotify"], "a moved rule keeps its new place")

// MARK: - Validation

section("validation")
let validRule = #""name": "Example", "bundleIdentifier": "com.example.app", "pattern": "^https://example\\.com/(.+)$""#
func withRule(_ fields: String) -> String {
    return #"{"version": 1, "rules": [{\#(fields)}]}"#
}

expectIssue("{", "truncated JSON", containing: "not valid JSON")
expectIssue(#"{"version": 1, "order": [}"#, "unclosed array", containing: "not valid JSON")
let (_, syntaxIssues) = parse("{\n  \"version\": 1\n  \"order\": []\n}")
expect(syntaxIssues.first?.message.contains("line") == true, "JSON syntax errors say where", "\(syntaxIssues)")
expectIssue("[]", "top-level array", containing: "top level must be an object")
expectIssue("{}", "missing version", field: "version", containing: "missing")
expectIssue(#"{"version": 3}"#, "unknown version", field: "version", containing: "not a known version")
expectIssue(#"{"version": 1.5}"#, "version between the known ones", field: "version", containing: "not a known version")
expectIssue(#"{"version": "1"}"#, "version as a string", field: "version", containing: "must be the number 2")
expectIssue(#"{"version": true}"#, "version as a boolean", field: "version", containing: "must be the number 2")
expectIssue(#"{"version": 1, "rule": []}"#, "unknown top-level key", field: "rule", containing: "unknown key")
expectIssue(#"{"version": 1, "order": "slack"}"#, "order not an array", field: "order", containing: "must be an array")
expectIssue(#"{"version": 1, "enabled": ["slack", 3]}"#, "enabled with a number", field: "enabled[1]", containing: "rule id string")
expectIssue(#"{"version": 1, "rules": {}}"#, "rules not an array", field: "rules", containing: "must be an array")
expectIssue(#"{"version": 1, "rules": ["x"]}"#, "rule not an object", ruleIndex: 0, containing: "must be an object")

expectIssue(withRule(#""name": "A", "bundleIdentifier": "b", "pattern": "x""#), "missing id", ruleIndex: 0, field: "id", containing: "missing")
expectIssue(withRule(#""id": 7, \#(validRule)"#), "id not a string", ruleIndex: 0, field: "id", containing: "must be a string")
expectIssue(withRule(#""id": "", \#(validRule)"#), "empty id", field: "id", containing: "must not be empty")
expectIssue(withRule(#""id": "My-Rule", \#(validRule)"#), "uppercase id", ruleIdentifier: "My-Rule", field: "id", containing: "lowercase letters")
expectIssue(withRule(#""id": "my rule", \#(validRule)"#), "id with a space", field: "id", containing: "lowercase letters")
expectIssue(withRule(#""id": "my_rule", \#(validRule)"#), "id with an underscore", field: "id", containing: "lowercase letters")
expectIssue(withRule(#""id": "-rule", \#(validRule)"#), "id starting with a hyphen", field: "id", containing: "must not start with a hyphen")
_ = expectValid(withRule(#""id": "slack", \#(validRule)"#), "a custom rule may use a built-in rule's id")
expectIssue(#"{"version": 1, "rules": [{"id": "dup", \#(validRule)}, {"id": "dup", \#(validRule)}]}"#,
            "duplicate id", ruleIndex: 1, ruleIdentifier: "dup", field: "id", containing: "must be unique")
expectIssue(withRule(#""id": "a", "bundleIdentifier": "b", "pattern": "x""#), "missing name", field: "name", containing: "missing")
expectIssue(withRule(#""id": "a", "name": "  ", "bundleIdentifier": "b", "pattern": "x""#), "blank name", ruleIdentifier: "a", field: "name", containing: "must not be empty")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": "", "pattern": "x""#), "empty bundle identifier", field: "bundleIdentifier", containing: "must not be empty")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": null, "pattern": "x""#), "null bundle identifier", field: "bundleIdentifier", containing: "missing")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": "b", "pattern": """#), "empty pattern", field: "pattern", containing: "must not be empty")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": "b", "pattern": "^https://(x""#), "unbalanced parenthesis", ruleIdentifier: "a", field: "pattern", containing: "not a valid regular expression")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": "b", "pattern": "[a-""#), "unterminated class", field: "pattern", containing: "not a valid regular expression")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": "b", "pattern": "*x""#), "dangling quantifier", field: "pattern", containing: "not a valid regular expression")
expectIssue(withRule(#""id": "a", \#(validRule), "rewrite": "x://$2""#), "rewrite group past the pattern's", ruleIdentifier: "a", field: "rewrite", containing: "uses $2, but the pattern has 1 capture group")
expectIssue(withRule(#""id": "a", "name": "A", "bundleIdentifier": "b", "pattern": "^https://x/", "rewrite": "x://$1""#), "rewrite group with no groups", field: "rewrite", containing: "no capture groups")
expectIssue(withRule(#""id": "a", \#(validRule), "rewrite": 5"#), "rewrite not a string", field: "rewrite", containing: "must be a string, null")
expectIssue(withRule(#""id": "a", \#(validRule), "rewriteTemplate": "x://$1""#), "unknown rule key (old field name)", field: "rewriteTemplate", containing: "unknown key")
_ = expectValid(withRule(#""id": "a", \#(validRule), "rewrite": "x://\\$2/$1""#), "escaped $ in rewrite is not a group")
_ = expectValid(withRule(#""id": "a", \#(validRule), "rewrite": "x://$0""#), "$0, the whole match, is allowed")
_ = expectValid(withRule(#""id": "rule-2", \#(validRule)"#), "id with digits and a hyphen")
_ = expectValid(#"{"version": 1, "rules": [{"id": "a", \#(validRule)}, {"id": "b", \#(validRule)}]}"#, "two rules")

// Several problems are all reported, with the rule they are in.
let (_, manyIssues) = parse(#"{"version": 3, "extra": 1, "rules": [{"id": "Bad", "name": "", "bundleIdentifier": "", "pattern": "("}, {"id": "ok", \#(validRule), "rewrite": "$1$4"}]}"#)
expect(manyIssues.count == 7, "all issues are collected", "\(manyIssues.map(\.description))")
expect(manyIssues.contains { $0.ruleIndex == 1 && $0.ruleIdentifier == "ok" && $0.field == "rewrite" && $0.message.contains("$4") },
       "issue names the rule and the field")
let issueText = AppLinkConfigIssue(ruleIndex: 2, ruleIdentifier: "my-rule", field: "pattern", "is broken").description
expect(issueText == #"rules[2] "my-rule", pattern: is broken"#, "issue description format", issueText)
expect(AppLinkConfigIssue(field: "version", "missing").description == "version: missing", "top-level issue format")

expect(AppLinkRuleValidator.referencedGroups(in: #"a$1b$2[&x=$3]$1\$4$"#) == [1, 2, 3], "referenced groups skip escapes and repeats",
       "\(AppLinkRuleValidator.referencedGroups(in: #"a$1b$2[&x=$3]$1\$4$"#))")
expect(AppLinkRuleValidator.referencedGroups(in: "$x$") == [], "$ without a digit is literal")

// MARK: - Identifiers and descriptions

section("identifiers and descriptions")
expect(AppLinkConfig.slug(from: "My App!") == "my-app", "slug")
expect(AppLinkConfig.slug(from: "  Linear  (Issues) ") == "linear-issues", "slug trims and collapses")
expect(AppLinkConfig.slug(from: "!!!") == "rule", "slug of punctuation")
expect(AppLinkConfig.slug(from: "Café 2") == "caf-2", "slug drops non-ASCII letters")
expect(AppLinkConfig.isValidIdentifier(AppLinkConfig.slug(from: "Ünïcode ☃ name")), "slugs are always valid ids")
expect(AppLinkConfig.uniqueIdentifier(base: "a", taken: []) == "a", "unique id when free")
expect(AppLinkConfig.uniqueIdentifier(base: "a", taken: ["a", "a-2"]) == "a-3", "unique id counts up")
expect(AppLinkConfig.uniqueIdentifier(base: "figma-copy", taken: Set(builtInOrder)) == "figma-copy", "copy id")
expect(AppLinkConfigParser.identifierProblems("slack", taken: []).isEmpty, "a built-in id is allowed in the file")
expect(AppLinkConfigParser.identifierProblems("slack", taken: ["slack"]).count == 1, "a repeated id is a problem")

expect(AppLinkCatalog.host(inPattern: #"^https://example\.com/(.+)$"#) == "example.com", "host from a simple pattern")
expect(AppLinkCatalog.host(inPattern: #"^https://linear\.app/([^/]+)"#) == "linear.app", "host followed by a path")
expect(AppLinkCatalog.host(inPattern: #"^https://example\.com$"#) == "example.com", "host at the end")
expect(AppLinkCatalog.host(inPattern: #"^https://(?:www\.)?example\.com/"#) == nil, "host with a group is not derived")
expect(AppLinkCatalog.host(inPattern: #"^https://[a-z]+\.example\.com/"#) == nil, "host with a class is not derived")
expect(AppLinkCatalog.host(inPattern: #"example"#) == nil, "no scheme, no host")
expect(AppLinkCatalog.summary(for: rule("custom")) == "Links from example.com", "custom summary from host")
expect(AppLinkCatalog.summary(for: rule("custom", pattern: "^https?://x")) == "^https?://x", "custom summary falls back to the pattern")
expect(AppLinkCatalog.summary(for: AppLinkCatalog.rules[0]) == AppLinkCatalog.summaries["figma"], "built-in summary")

// MARK: - Writing

section("writing")
let written = String(decoding: AppLinkConfigSerializer.data(for: try! AppLinkConfigParser.parse(data(example))), as: UTF8.self)
let expectedText = #"""
{
  "version": 2,
  "order": ["my-rule", "slack", "figma", "linear"],
  "enabled": ["my-rule", "slack", "linear"],
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

"""#
expect(written == expectedText, "the example writes in the documented layout", "got:\n\(written)")
let emptyText = String(decoding: AppLinkConfigSerializer.data(for: AppLinkConfig(order: [], enabled: [], customRules: [])), as: UTF8.self)
expect(emptyText == "{\n  \"version\": 2,\n  \"order\": [],\n  \"enabled\": [],\n  \"rules\": []\n}\n", "empty config layout", emptyText)

let tricky = AppLinkConfig(
    order: ["q", "slack"], enabled: ["q"],
    customRules: [
        AppLinkRule(id: "q", name: "Quote \"and\" back\\slash\ttab é ☃", bundleIdentifier: "com.example.q",
                    pattern: #"^https://q\.example/(\d+)\?a=(.*)$"#, rewriteTemplate: nil, isEnabled: false),
        AppLinkRule(id: "r", name: "Control \u{1}", bundleIdentifier: "com.example.r",
                    pattern: "^x:(.)", rewriteTemplate: #"y:\$1[&z=$1]"#, isEnabled: false),
    ])
let trickyData = AppLinkConfigSerializer.data(for: tricky)
let trickyText = String(decoding: trickyData, as: UTF8.self)
expect((try? AppLinkConfigParser.parse(trickyData)) == tricky, "quotes, backslashes, tabs, control and non-ASCII characters round-trip", trickyText)
expect(!trickyText.contains("\"rewrite\": null") && trickyText.components(separatedBy: "\"rewrite\"").count == 2,
       "a nil rewrite is left out")
expect(trickyText.contains(#"\u0001"#), "control characters are escaped")
expect(trickyText.contains("https://"), "slashes are not escaped")
expect(AppLinkConfigSerializer.data(for: tricky) == trickyData, "writing is stable")
let reparsedExample = try! AppLinkConfigParser.parse(data(written))
expect(AppLinkConfigSerializer.data(for: reparsedExample) == data(written), "write, read, write gives the same bytes")
expect((try? JSONSerialization.jsonObject(with: trickyData)) != nil, "output is valid JSON")

// MARK: - Matching

section("matching")
let figmaLink = "https://www.figma.com/design/KEY/File"
let catalogOn = AppLinkCatalog.rules.map { r -> AppLinkRule in var r = r; r.isEnabled = true; return r }
let installedAll: (AppLinkRule) -> Bool = { _ in true }

if case let .app(r, url) = AppLinkMatcher.match(figmaLink, rules: catalogOn, isInstalled: installedAll) {
    expect(r.id == "figma" && url.absoluteString == figmaLink, "enabled installed built-in matches")
} else {
    expect(false, "enabled installed built-in matches")
}
expect(AppLinkMatcher.match("https://example.org/", rules: catalogOn, isInstalled: installedAll) == .browser(unavailable: nil),
       "no match goes to the browser")
expect(AppLinkMatcher.match(figmaLink, rules: AppLinkCatalog.rules, isInstalled: installedAll) == .browser(unavailable: nil),
       "disabled rules don't match, and say nothing unless asked")
if case .browser(unavailable: let r?) = AppLinkMatcher.match(figmaLink, rules: AppLinkCatalog.rules, isInstalled: installedAll, reportUnavailable: true) {
    expect(r.id == "figma" && !r.isEnabled, "a matching rule that is off is reported")
} else {
    expect(false, "a matching rule that is off is reported")
}
if case .browser(unavailable: let r?) = AppLinkMatcher.match(figmaLink, rules: catalogOn, isInstalled: { $0.id != "figma" }, reportUnavailable: true) {
    expect(r.id == "figma" && r.isEnabled, "a matching rule whose app is missing is reported")
} else {
    expect(false, "a matching rule whose app is missing is reported")
}
expect(AppLinkMatcher.match(figmaLink, rules: catalogOn, isInstalled: installedAll, skippingBundleIdentifiers: ["com.figma.Desktop"]) == .browser(unavailable: nil),
       "a rule for the sending app is skipped")

// First match wins, and order decides it.
let catchAllA = rule("catch-a", pattern: "^https://", rewrite: nil, bundle: "com.example.a", enabled: true)
let catchAllB = rule("catch-b", pattern: "^https://.*$", rewrite: "b:$0", bundle: "com.example.b", enabled: true)
if case let .app(r, _) = AppLinkMatcher.match(figmaLink, rules: [catchAllA] + catalogOn, isInstalled: installedAll) {
    expect(r.id == "catch-a", "a custom rule above a built-in wins")
} else { expect(false, "a custom rule above a built-in wins") }
if case let .app(r, _) = AppLinkMatcher.match(figmaLink, rules: catalogOn + [catchAllA], isInstalled: installedAll) {
    expect(r.id == "figma", "a built-in above a custom rule wins")
} else { expect(false, "a built-in above a custom rule wins") }
if case let .app(r, url) = AppLinkMatcher.match(figmaLink, rules: [catchAllA, catchAllB], isInstalled: { $0.id == "catch-b" }) {
    expect(r.id == "catch-b" && url.absoluteString == "b:" + figmaLink, "an uninstalled rule falls through to the next", url.absoluteString)
} else { expect(false, "an uninstalled rule falls through to the next") }
let badRewrite = rule("bad", pattern: "^https://(x?)", rewrite: "$1", bundle: "com.example.bad", enabled: true)
if case let .app(r, _) = AppLinkMatcher.match(figmaLink, rules: [badRewrite, catchAllA], isInstalled: installedAll) {
    expect(r.id == "catch-a", "a rule whose rewrite is not a URL falls through")
} else { expect(false, "a rule whose rewrite is not a URL falls through") }
expect(badRewrite.patternMatches(figmaLink) && badRewrite.destinationURL(for: figmaLink) == nil, "patternMatches without a destination")

// The whole path: file text to routing decision.
if let config = expectValid(example, "example for routing") {
    let rules = config.resolvedRules()
    if case let .app(r, url) = AppLinkMatcher.match("https://example.com/acme/1", rules: rules, isInstalled: installedAll) {
        expect(r.id == "my-rule" && url.absoluteString == "example://acme/1", "example rule routes")
    } else { expect(false, "example rule routes") }
    if case let .app(r, _) = AppLinkMatcher.match("https://app.slack.com/client/T01ABCDEF/C02GHIJKL", rules: rules, isInstalled: installedAll) {
        expect(r.id == "slack", "enabled built-in routes from the file")
    } else { expect(false, "enabled built-in routes from the file") }
    expect(AppLinkMatcher.match(figmaLink, rules: rules, isInstalled: installedAll) == .browser(unavailable: nil),
           "built-in left out of enabled stays off")
}

// MARK: - Store

section("store")
let scratch = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : NSTemporaryDirectory())
    .appendingPathComponent("store-\(UUID().uuidString)", isDirectory: true)
let configURL = scratch.appendingPathComponent("nested/app-links.json")
expect(AppLinkConfigFile.defaultURL(environment: [AppLinkConfigFile.environmentKey: configURL.path]) == configURL,
       "the environment variable overrides the path")
expect(AppLinkConfigFile.defaultURL(environment: [:]).path.hasSuffix("Library/Application Support/PerSpaceLinkRouter/app-links.json"),
       "default path is in Application Support", AppLinkConfigFile.defaultURL(environment: [:]).path)
expect(AppLinkConfigFile.defaultURL(environment: [AppLinkConfigFile.environmentKey: ""]) == AppLinkConfigFile.defaultURL(environment: [:]),
       "an empty override is ignored")

let queue = DispatchQueue(label: "check.store")
var defaultsReads = 0
var defaultsEnabled: Set<String> = ["zoom"]
let store = queue.sync {
    AppLinkConfigStore(fileURL: configURL, queue: queue, fallbackEnabledIdentifiers: {
        defaultsReads += 1
        return defaultsEnabled
    })
}
func onQueue<T>(_ work: () -> T) -> T { return queue.sync(execute: work) }

expect(onQueue { !store.fileExists && !store.isUsingFile }, "no file at first")
expect(onQueue { enabledIDs(store.rules) } == ["zoom"], "no file: the UserDefaults set is in effect")
expect(onQueue { store.issues.isEmpty }, "no file is not an error")

// The first write migrates the UserDefaults set into the file.
onQueue { try! store.createFileIfNeeded() }
expect(FileManager.default.fileExists(atPath: configURL.path), "createFileIfNeeded writes the file, creating its folder")
let migrated = try! AppLinkConfigParser.parse(Data(contentsOf: configURL))
expect(migrated.enabled == ["zoom"] && migrated.order == builtInOrder && migrated.customRules.isEmpty,
       "the file holds the migrated set")
defaultsEnabled = ["figma"]
let readsBefore = defaultsReads
onQueue { store.reload() }
expect(onQueue { enabledIDs(store.rules) } == ["zoom"] && defaultsReads == readsBefore,
       "once the file exists, UserDefaults is not read")

// Saving from the window.
var edited = onQueue { store.rules }
edited.insert(rule("my-rule", enabled: true), at: 0)
onQueue { try! store.save(AppLinkConfig(rules: edited)) }
expect(onQueue { ids(store.rules).first == "my-rule" && store.isUsingFile }, "save puts the new rules in effect")
let savedText = try! String(contentsOf: configURL, encoding: .utf8)
expect(savedText.contains("\"my-rule\"") && savedText.hasSuffix("}\n"), "save writes the file")
var invalid = edited
invalid[0] = rule("my-rule", rewrite: "x://$5", enabled: true)
var saveRefused = false
onQueue {
    do { try store.save(AppLinkConfig(rules: invalid)) } catch is AppLinkConfigError { saveRefused = true } catch {}
}
expect(saveRefused, "an invalid config is never written")
expect(try! String(contentsOf: configURL, encoding: .utf8) == savedText, "a refused save leaves the file alone")

// A bad edit keeps the last good rules and reports why.
var notifications = 0
let observer = NotificationCenter.default.addObserver(forName: AppLinkConfigStore.didChangeNotification, object: store, queue: nil) { _ in
    notifications += 1
}
try! Data("{\"version\": 1, \"rules\": [{\"id\": \"BAD\"}]}".utf8).write(to: configURL)
onQueue { store.reload() }
expect(onQueue { ids(store.rules).first == "my-rule" && enabledIDs(store.rules) == ["my-rule", "zoom"] },
       "an invalid file leaves the last good rules running")
expect(onQueue { store.issues.contains { $0.ruleIdentifier == "BAD" && $0.field == "id" } }, "the store reports the issues")
expect(notifications == 1, "an invalid file notifies", "\(notifications)")
onQueue { store.reload() }
expect(notifications == 1, "reloading identical bytes does not notify again")
var overwrote = false
onQueue { do { try store.createFileIfNeeded(); overwrote = (try? AppLinkConfigParser.parse(Data(contentsOf: configURL))) != nil } catch {} }
expect(!overwrote, "createFileIfNeeded does not replace an invalid file")
try! Data(savedText.utf8).write(to: configURL)
onQueue { store.reload() }
expect(onQueue { store.issues.isEmpty && ids(store.rules).first == "my-rule" }, "fixing the file clears the issues")

// Deleting the file goes back to the built-in rules and UserDefaults set.
try! FileManager.default.removeItem(at: configURL)
onQueue { store.reload() }
expect(onQueue { !store.isUsingFile && ids(store.rules) == builtInOrder && enabledIDs(store.rules) == ["figma"] },
       "a deleted file falls back to UserDefaults")

// Launching with a bad file runs the fallback and reports the file.
try! Data("not json".utf8).write(to: configURL)
let badLaunch = queue.sync { AppLinkConfigStore(fileURL: configURL, queue: queue, fallbackEnabledIdentifiers: { ["slack"] }) }
expect(onQueue { enabledIDs(badLaunch.rules) == ["slack"] && badLaunch.issues.first?.message.hasPrefix("not valid JSON") == true },
       "launching with a bad file uses the fallback and shows the error")

// MARK: - Watching

section("watching")
try! Data(savedText.utf8).write(to: configURL)
onQueue { store.reload() }
let changed = DispatchSemaphore(value: 0)
let watchObserver = NotificationCenter.default.addObserver(forName: AppLinkConfigStore.didChangeNotification, object: store, queue: nil) { _ in
    changed.signal()
}
onQueue { store.startWatching() }
func waitForChange(_ label: String, _ condition: @escaping () -> Bool) {
    let deadline = Date().addingTimeInterval(5)
    var satisfied = false
    while Date() < deadline {
        _ = changed.wait(timeout: .now() + 0.25)
        if onQueue(condition) { satisfied = true; break }
    }
    expect(satisfied, "reloads on change: \(label)")
}
func configText(order: [String], enabled: [String]) -> Data {
    return AppLinkConfigSerializer.data(for: AppLinkConfig(order: order, enabled: enabled, customRules: []))
}

// An editor that saves by writing a new file and renaming it over the old one.
let replacement = configURL.deletingLastPathComponent().appendingPathComponent(".app-links.json.tmp")
try! configText(order: ["spotify"], enabled: ["spotify"]).write(to: replacement)
_ = rename(replacement.path, configURL.path)
waitForChange("replaced by rename") { enabledIDs(store.rules) == ["spotify"] && ids(store.rules).first == "spotify" }

// An editor that writes in place.
let handle = try! FileHandle(forWritingTo: configURL)
handle.truncateFile(atOffset: 0)
handle.write(configText(order: ["discord"], enabled: ["discord"]))
handle.closeFile()
waitForChange("written in place") { enabledIDs(store.rules) == ["discord"] }

// Data.write(options: .atomic), which is what the app itself uses.
try! configText(order: ["zoom", "slack"], enabled: ["zoom", "slack"]).write(to: configURL, options: .atomic)
waitForChange("atomic write") { enabledIDs(store.rules) == ["zoom", "slack"] }

// A second in-place write after the replacement, so the re-armed watch works.
try! configText(order: ["figma"], enabled: ["figma"]).write(to: configURL)
waitForChange("written again after replacement") { enabledIDs(store.rules) == ["figma"] }

// A broken save, then a fix.
try! Data("{ \"version\": 1, ".utf8).write(to: configURL)
waitForChange("broken file reports issues") { !store.issues.isEmpty && enabledIDs(store.rules) == ["figma"] }
try! configText(order: ["slack"], enabled: ["slack"]).write(to: configURL)
waitForChange("fixed file clears issues") { store.issues.isEmpty && enabledIDs(store.rules) == ["slack"] }

// Removed, then created again.
try! FileManager.default.removeItem(at: configURL)
waitForChange("deleted") { !store.isUsingFile }
try! configText(order: ["spotify"], enabled: ["spotify"]).write(to: configURL)
waitForChange("created again") { store.isUsingFile && enabledIDs(store.rules) == ["spotify"] }

onQueue { store.stopWatching() }
NotificationCenter.default.removeObserver(observer)
NotificationCenter.default.removeObserver(watchObserver)
try? FileManager.default.removeItem(at: scratch)

print(failures == 0 ? "\nall \(passed) checks passed" : "\n\(failures) failure(s), \(passed) passed")
exit(failures == 0 ? 0 : 1)
