//
//  AppLinkConfig.swift
//  PerSpaceLinkRouter
//
//  The app-links.json config file: parsing, validation, match order, writing,
//  and the matching shared by real routing and "Test a link". Foundation
//  only, so bin/check-app-link-rules can compile it without the app. Never
//  logs URLs or matched text.
//

import Foundation

/// What app-links.json holds: the custom rules, the match order of every
/// rule, and which rules are on. Built-in rules stay in code
/// (`AppLinkCatalog`); the file names them only in `order` and `enabled`.
struct AppLinkConfig: Equatable {

    static let currentVersion = 1

    /// Rule ids in match order. May name ids that no longer exist.
    var order: [String]
    /// Ids of the rules that are on.
    var enabled: [String]
    /// Custom rules, in file order. Their `isEnabled` is not used; `enabled`
    /// is the only record of which rules are on.
    var customRules: [AppLinkRule]

    /// The config used before app-links.json exists: the built-in rules in
    /// catalog order, with the enabled set kept in UserDefaults by earlier
    /// versions.
    static func fallback(enabledIdentifiers: Set<String>, builtIns: [AppLinkRule] = AppLinkCatalog.rules) -> AppLinkConfig {
        let order = builtIns.map(\.id)
        return AppLinkConfig(order: order, enabled: order.filter { enabledIdentifiers.contains($0) }, customRules: [])
    }

    /// The config that describes a list of rules in match order, as the
    /// settings window holds them.
    init(rules: [AppLinkRule], builtIns: [AppLinkRule] = AppLinkCatalog.rules) {
        let builtInIdentifiers = Set(builtIns.map(\.id))
        order = rules.map(\.id)
        enabled = rules.filter(\.isEnabled).map(\.id)
        customRules = rules.filter { !builtInIdentifiers.contains($0.id) }.map { rule in
            var rule = rule
            rule.isEnabled = false
            return rule
        }
    }

    init(order: [String], enabled: [String], customRules: [AppLinkRule]) {
        self.order = order
        self.enabled = enabled
        self.customRules = customRules
    }

    /// Every rule, built-in and custom, in match order with `isEnabled` set.
    ///
    /// Ids in `order` come first. Unknown ids are skipped, and a repeated id
    /// counts only at its first place. Custom rules missing from `order`
    /// follow in file order, then built-in rules missing from it in catalog
    /// order, so a built-in rule added by a later release shows up at the
    /// end.
    func resolvedRules(builtIns: [AppLinkRule] = AppLinkCatalog.rules) -> [AppLinkRule] {
        var byIdentifier: [String: AppLinkRule] = [:]
        for rule in builtIns {
            byIdentifier[rule.id] = rule
        }
        for rule in customRules where byIdentifier[rule.id] == nil {
            byIdentifier[rule.id] = rule
        }
        let enabledSet = Set(enabled)
        var placed = Set<String>()
        var result: [AppLinkRule] = []
        func place(_ identifier: String) {
            guard !placed.contains(identifier), var rule = byIdentifier[identifier] else {
                return
            }
            placed.insert(identifier)
            rule.isEnabled = enabledSet.contains(identifier)
            result.append(rule)
        }
        order.forEach(place)
        customRules.map(\.id).forEach(place)
        builtIns.map(\.id).forEach(place)
        return result
    }

    // MARK: - Identifiers

    /// Lowercase letters, digits, and hyphens, starting with a letter or digit.
    static func isValidIdentifier(_ identifier: String) -> Bool {
        guard let first = identifier.unicodeScalars.first, first != "-" else {
            return false
        }
        return identifier.unicodeScalars.allSatisfy { scalar in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-"
        }
    }

    /// An identifier made from a rule's name: "My App!" becomes "my-app".
    static func slug(from name: String) -> String {
        var slug = ""
        var pendingHyphen = false
        for scalar in name.lowercased().unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                if pendingHyphen && !slug.isEmpty {
                    slug += "-"
                }
                pendingHyphen = false
                slug.unicodeScalars.append(scalar)
            } else {
                pendingHyphen = true
            }
        }
        return slug.isEmpty ? "rule" : slug
    }

    /// `base`, or `base-2`, `base-3`... whichever is not taken.
    static func uniqueIdentifier(base: String, taken: Set<String>) -> String {
        if !taken.contains(base) {
            return base
        }
        var number = 2
        while taken.contains("\(base)-\(number)") {
            number += 1
        }
        return "\(base)-\(number)"
    }

}

// MARK: - Issues

/// One problem with app-links.json or with a rule being edited.
struct AppLinkConfigIssue: Equatable, CustomStringConvertible {

    /// Position in the file's `rules` array, when the issue is in a rule.
    var ruleIndex: Int?
    /// The rule's id, when it has a readable one.
    var ruleIdentifier: String?
    /// The key the issue is about, such as `pattern`.
    var field: String?
    var message: String

    init(ruleIndex: Int? = nil, ruleIdentifier: String? = nil, field: String? = nil, _ message: String) {
        self.ruleIndex = ruleIndex
        self.ruleIdentifier = ruleIdentifier
        self.field = field
        self.message = message
    }

    /// For example `rules[1] "my-rule", pattern: doesn't compile...`.
    var description: String {
        var location: [String] = []
        if let ruleIndex = ruleIndex {
            var rule = "rules[\(ruleIndex)]"
            if let identifier = ruleIdentifier, !identifier.isEmpty {
                rule += " \"\(identifier)\""
            }
            location.append(rule)
        }
        if let field = field {
            location.append(field)
        }
        return location.isEmpty ? message : location.joined(separator: ", ") + ": " + message
    }

}

struct AppLinkConfigError: Error, Equatable, CustomStringConvertible {
    var issues: [AppLinkConfigIssue]

    var description: String {
        return issues.map(\.description).joined(separator: "\n")
    }
}

// MARK: - Parsing and validation

enum AppLinkConfigParser {

    static let topLevelKeys: Set<String> = ["version", "order", "enabled", "rules"]
    static let ruleKeys: Set<String> = ["id", "name", "bundleIdentifier", "pattern", "rewrite"]

    /// Parses and validates app-links.json. Throws `AppLinkConfigError` with
    /// every issue found, not just the first.
    static func parse(_ data: Data, builtIns: [AppLinkRule] = AppLinkCatalog.rules) throws -> AppLinkConfig {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            // JSONSerialization puts the line and column in the debug description.
            let detail = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String
            throw AppLinkConfigError(issues: [AppLinkConfigIssue("not valid JSON" + (detail.map { ": \($0)" } ?? ""))])
        }
        guard let root = object as? [String: Any] else {
            throw AppLinkConfigError(issues: [AppLinkConfigIssue("the top level must be an object")])
        }

        var issues: [AppLinkConfigIssue] = []

        for key in root.keys.sorted() where !topLevelKeys.contains(key) {
            issues.append(AppLinkConfigIssue(field: key, "unknown key; expected version, order, enabled, and rules"))
        }

        switch root["version"] {
        case nil:
            issues.append(AppLinkConfigIssue(field: "version", "missing; set it to \(AppLinkConfig.currentVersion)"))
        case let number as NSNumber where !isBoolean(number) && number.doubleValue == Double(AppLinkConfig.currentVersion):
            break
        case let number as NSNumber where !isBoolean(number):
            issues.append(AppLinkConfigIssue(field: "version", "\(number) is not a known version; this app reads version \(AppLinkConfig.currentVersion)"))
        default:
            issues.append(AppLinkConfigIssue(field: "version", "must be the number \(AppLinkConfig.currentVersion)"))
        }

        let order = stringArray(root["order"], field: "order", issues: &issues)
        let enabled = stringArray(root["enabled"], field: "enabled", issues: &issues)

        var customRules: [AppLinkRule] = []
        switch root["rules"] {
        case nil, is NSNull:
            break
        case let array as [Any]:
            let builtInIdentifiers = Set(builtIns.map(\.id))
            var seen = Set<String>()
            for (index, element) in array.enumerated() {
                guard let dictionary = element as? [String: Any] else {
                    issues.append(AppLinkConfigIssue(ruleIndex: index, "must be an object"))
                    continue
                }
                if let rule = parseRule(dictionary, index: index, builtInIdentifiers: builtInIdentifiers, seen: &seen, issues: &issues) {
                    customRules.append(rule)
                }
            }
        default:
            issues.append(AppLinkConfigIssue(field: "rules", "must be an array of rule objects"))
        }

        if !issues.isEmpty {
            throw AppLinkConfigError(issues: issues)
        }
        return AppLinkConfig(order: order, enabled: enabled, customRules: customRules)
    }

    private static func parseRule(_ dictionary: [String: Any], index: Int, builtInIdentifiers: Set<String>, seen: inout Set<String>, issues: inout [AppLinkConfigIssue]) -> AppLinkRule? {
        let readableIdentifier = dictionary["id"] as? String
        let issueCount = issues.count
        func issue(_ field: String?, _ message: String) {
            issues.append(AppLinkConfigIssue(ruleIndex: index, ruleIdentifier: readableIdentifier, field: field, message))
        }

        for key in dictionary.keys.sorted() where !ruleKeys.contains(key) {
            issue(key, "unknown key; a rule has id, name, bundleIdentifier, pattern, and rewrite")
        }

        func requiredString(_ key: String) -> String? {
            switch dictionary[key] {
            case nil, is NSNull:
                issue(key, "missing")
                return nil
            case let value as String:
                return value
            default:
                issue(key, "must be a string")
                return nil
            }
        }

        let identifier = requiredString("id")
        let name = requiredString("name")
        let bundleIdentifier = requiredString("bundleIdentifier")
        let pattern = requiredString("pattern")
        var rewrite: String?
        switch dictionary["rewrite"] {
        case nil, is NSNull:
            rewrite = nil
        case let value as String:
            rewrite = value
        default:
            issue("rewrite", "must be a string, null, or left out")
        }

        if let identifier = identifier {
            for message in identifierProblems(identifier, builtInIdentifiers: builtInIdentifiers, taken: seen) {
                issue("id", message)
            }
            seen.insert(identifier)
        }

        if let name = name, let bundleIdentifier = bundleIdentifier, let pattern = pattern {
            let rule = AppLinkRule(id: identifier ?? "", name: name, bundleIdentifier: bundleIdentifier,
                                   pattern: pattern, rewriteTemplate: normalizedRewrite(rewrite), isEnabled: false)
            for problem in AppLinkRuleValidator.issues(for: rule) {
                issue(problem.field, problem.message)
            }
            return issues.count == issueCount ? rule : nil
        }
        return nil
    }

    /// Why `identifier` cannot name a new custom rule, if it can't.
    static func identifierProblems(_ identifier: String, builtInIdentifiers: Set<String>, taken: Set<String>) -> [String] {
        if identifier.isEmpty {
            return ["must not be empty"]
        }
        var problems: [String] = []
        if !AppLinkConfig.isValidIdentifier(identifier) {
            problems.append("\"\(identifier)\" may only use lowercase letters, digits, and hyphens, and must not start with a hyphen")
        }
        if builtInIdentifiers.contains(identifier) {
            problems.append("\"\(identifier)\" is a built-in rule's id; pick another")
        } else if taken.contains(identifier) {
            problems.append("\"\(identifier)\" is used by an earlier rule; ids must be unique")
        }
        return problems
    }

    /// An empty rewrite means the same as none: pass the link through.
    static func normalizedRewrite(_ rewrite: String?) -> String? {
        guard let rewrite = rewrite, !rewrite.isEmpty else {
            return nil
        }
        return rewrite
    }

    private static func stringArray(_ value: Any?, field: String, issues: inout [AppLinkConfigIssue]) -> [String] {
        switch value {
        case nil, is NSNull:
            return []
        case let array as [Any]:
            var strings: [String] = []
            for (index, element) in array.enumerated() {
                if let string = element as? String {
                    strings.append(string)
                } else {
                    issues.append(AppLinkConfigIssue(field: "\(field)[\(index)]", "must be a rule id string"))
                }
            }
            return strings
        default:
            issues.append(AppLinkConfigIssue(field: field, "must be an array of rule id strings"))
            return []
        }
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

}

/// Checks a rule's fields other than its id. Used for the file and for the
/// rule being edited in the settings window.
enum AppLinkRuleValidator {

    static func issues(for rule: AppLinkRule) -> [AppLinkConfigIssue] {
        var issues: [AppLinkConfigIssue] = []
        if rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(AppLinkConfigIssue(field: "name", "must not be empty"))
        }
        if rule.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(AppLinkConfigIssue(field: "bundleIdentifier", "must not be empty; choose the app the links open in"))
        }
        if rule.pattern.isEmpty {
            issues.append(AppLinkConfigIssue(field: "pattern", "must not be empty"))
            return issues
        }
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive])
        } catch {
            issues.append(AppLinkConfigIssue(field: "pattern", "is not a valid regular expression; check for unbalanced parentheses or brackets, and escape literal characters such as . ? + with \\"))
            return issues
        }
        if let template = rule.rewriteTemplate {
            let groups = regex.numberOfCaptureGroups
            let missing = referencedGroups(in: template).filter { $0 > groups }
            if !missing.isEmpty {
                let names = missing.map { "$\($0)" }.joined(separator: ", ")
                let available = groups == 0 ? "the pattern has no capture groups" : "the pattern has \(groups) capture group\(groups == 1 ? "" : "s") ($1\(groups > 1 ? "...$\(groups)" : ""))"
                issues.append(AppLinkConfigIssue(field: "rewrite", "uses \(names), but \(available)"))
            }
        }
        return issues
    }

    /// The group numbers a rewrite template refers to, in order, without
    /// repeats. Follows `AppLinkRule.expand`: `\` escapes the next character
    /// and `$` takes one digit.
    static func referencedGroups(in template: String) -> [Int] {
        var groups: [Int] = []
        var characters = template.makeIterator()
        while let character = characters.next() {
            switch character {
            case "\\":
                _ = characters.next()
            case "$":
                if let next = characters.next(), let index = next.wholeNumberValue, !groups.contains(index) {
                    groups.append(index)
                }
            default:
                break
            }
        }
        return groups
    }

}

// MARK: - Writing

enum AppLinkConfigSerializer {

    /// Pretty-printed JSON with a fixed key order (version, order, enabled,
    /// rules; and id, name, bundleIdentifier, pattern, rewrite in each rule),
    /// so diffs of the file stay small. A rule with no rewrite leaves the key
    /// out. Ends with a newline.
    static func data(for config: AppLinkConfig) -> Data {
        var lines: [String] = ["{"]
        lines.append("  \"version\": \(AppLinkConfig.currentVersion),")
        lines.append("  \"order\": \(inlineArray(config.order)),")
        lines.append("  \"enabled\": \(inlineArray(config.enabled)),")
        if config.customRules.isEmpty {
            lines.append("  \"rules\": []")
        } else {
            lines.append("  \"rules\": [")
            for (index, rule) in config.customRules.enumerated() {
                var fields = [
                    ("id", rule.id),
                    ("name", rule.name),
                    ("bundleIdentifier", rule.bundleIdentifier),
                    ("pattern", rule.pattern),
                ]
                if let rewrite = rule.rewriteTemplate {
                    fields.append(("rewrite", rewrite))
                }
                lines.append("    {")
                for (fieldIndex, field) in fields.enumerated() {
                    let comma = fieldIndex == fields.count - 1 ? "" : ","
                    lines.append("      \(quoted(field.0)): \(quoted(field.1))\(comma)")
                }
                lines.append("    }" + (index == config.customRules.count - 1 ? "" : ","))
            }
            lines.append("  ]")
        }
        lines.append("}")
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func inlineArray(_ strings: [String]) -> String {
        return "[" + strings.map(quoted).joined(separator: ", ") + "]"
    }

    /// A JSON string literal. Slashes are left alone so URLs stay readable.
    static func quoted(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20:
                result += String(format: "\\u%04x", scalar.value)
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

}

// MARK: - Matching

/// Where a link goes.
enum AppLinkMatch: Equatable {
    /// The first enabled, installed rule that matches, and the URL the app
    /// receives.
    case app(AppLinkRule, URL)
    /// No enabled, installed rule matches. `unavailable` is the first rule
    /// that would match but is off or whose app is not installed, when
    /// asked for.
    case browser(unavailable: AppLinkRule?)
}

enum AppLinkMatcher {

    /// The routing decision for a link. Real routing and "Test a link" both
    /// call this; routing also passes the apps to skip (the link's sender
    /// and the frontmost app), and handles the Option key itself.
    ///
    /// - Parameters:
    ///   - rules: every rule in match order, with `isEnabled` set.
    ///   - isInstalled: whether a rule's app is on this Mac.
    ///   - skippingBundleIdentifiers: rules for these apps are passed over.
    ///   - reportUnavailable: also find the first matching rule that is off
    ///     or not installed, for explaining why a link goes to the browser.
    static func match(_ urlString: String, rules: [AppLinkRule], isInstalled: (AppLinkRule) -> Bool,
                      skippingBundleIdentifiers: Set<String> = [], reportUnavailable: Bool = false) -> AppLinkMatch {
        var unavailable: AppLinkRule?
        for rule in rules {
            if rule.isEnabled {
                if skippingBundleIdentifiers.contains(rule.bundleIdentifier) {
                    continue
                }
                guard let url = rule.destinationURL(for: urlString) else {
                    continue
                }
                if isInstalled(rule) {
                    return .app(rule, url)
                }
                if reportUnavailable && unavailable == nil {
                    unavailable = rule
                }
            } else if reportUnavailable && unavailable == nil && rule.destinationURL(for: urlString) != nil {
                unavailable = rule
            }
        }
        return .browser(unavailable: unavailable)
    }

}

extension AppLinkRule {

    /// Whether the pattern matches, whatever the rewrite makes of it. A rule
    /// can match and still have no destination when its rewrite does not
    /// produce a valid URL.
    func patternMatches(_ urlString: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        return regex.firstMatch(in: urlString, options: [], range: NSRange(urlString.startIndex..., in: urlString)) != nil
    }

}
