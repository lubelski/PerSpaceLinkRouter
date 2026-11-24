//
//  AppLinksSettingsView.swift
//  PerSpaceLinkRouter
//
//  The App Links page: the rules in use in match order, adding from the
//  gallery, custom rules, the edit sheet, and "Test a link". Nothing here
//  opens or logs a tested link.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model actions

extension SettingsModel {

    var appLinksFileURL: URL {
        return appLinkRouter.store.fileURL
    }

    /// The window only writes the file while it is valid, so a broken file
    /// someone is fixing by hand is never overwritten.
    var appLinksAreEditable: Bool {
        return appLinkIssues.isEmpty
    }

    /// Applies `change` to the rules in effect and writes the result. The
    /// first write also creates the file.
    private func updateAppLinkRules(_ change: (inout [AppLinkRule]) -> Void) {
        guard appLinksAreEditable else {
            return
        }
        var rules = appLinkRouter.rules
        change(&rules)
        do {
            try appLinkRouter.store.save(AppLinkConfig(rules: rules))
            appLinkSaveError = nil
        } catch let error as AppLinkConfigError {
            appLinkSaveError = "Couldn't save \(AppLinkConfigFile.fileName): \(error.description)"
        } catch {
            NSLog("Failed to write \(AppLinkConfigFile.fileName): \((error as NSError).domain) \((error as NSError).code)")
            appLinkSaveError = "Couldn't save \(AppLinkConfigFile.fileName): \(error.localizedDescription)"
        }
        refreshAppLinks()
    }

    func setAppLinkRule(identifier: String, enabled: Bool) {
        updateAppLinkRules { rules in
            if let index = rules.firstIndex(where: { $0.id == identifier }) {
                rules[index].isEnabled = enabled
            }
        }
    }

    func moveAppLinkRules(fromOffsets source: IndexSet, toOffset destination: Int) {
        updateAppLinkRules { $0.move(fromOffsets: source, toOffset: destination) }
    }

    /// Saves a new or edited custom rule and returns its id. A new rule goes
    /// to the top of the list, turned on, so it wins over the rules below.
    @discardableResult
    func saveCustomAppLinkRule(_ draft: AppLinkRuleDraft) -> String {
        var identifier = draft.originalIdentifier ?? ""
        updateAppLinkRules { rules in
            if let original = draft.originalIdentifier, let index = rules.firstIndex(where: { $0.id == original }) {
                rules[index] = draft.rule(identifier: original, isEnabled: rules[index].isEnabled)
            } else {
                // A new custom rule stays clear of gallery ids, so it never
                // takes a gallery rule's place by accident.
                identifier = AppLinkConfig.uniqueIdentifier(base: AppLinkConfig.slug(from: draft.name),
                                                            taken: Set(rules.map(\.id)).union(AppLinkCatalog.identifiers))
                rules.insert(draft.rule(identifier: identifier, isEnabled: true), at: 0)
            }
        }
        return identifier
    }

    /// Takes a rule out of the list. A custom rule is deleted. A built-in
    /// rule goes back to the gallery.
    func removeAppLinkRule(identifier: String) {
        updateAppLinkRules { rules in
            rules.removeAll { $0.id == identifier }
        }
    }

    /// Adds a gallery rule to the end of the list, turned on. The rules
    /// don't overlap, so its place only matters against custom rules.
    func addGalleryAppLinkRule(identifier: String) {
        updateAppLinkRules { rules in
            guard !rules.contains(where: { $0.id == identifier }),
                  var rule = AppLinkCatalog.rule(identifier: identifier) else {
                return
            }
            rule.isEnabled = true
            rules.append(rule)
        }
    }

    /// Adds an editable custom copy of any rule just below it, turned off,
    /// and returns the copy's id.
    func duplicateAppLinkRule(identifier: String) -> String? {
        var copyIdentifier: String?
        updateAppLinkRules { rules in
            guard let index = rules.firstIndex(where: { $0.id == identifier }) else {
                return
            }
            let original = rules[index]
            let newIdentifier = AppLinkConfig.uniqueIdentifier(base: "\(original.id)-copy",
                                                               taken: Set(rules.map(\.id)).union(AppLinkCatalog.identifiers))
            let copy = AppLinkRule(id: newIdentifier, name: "\(original.name) copy",
                                   bundleIdentifier: original.bundleIdentifier, pattern: original.pattern,
                                   rewriteTemplate: original.rewriteTemplate, isEnabled: false)
            rules.insert(copy, at: index + 1)
            copyIdentifier = newIdentifier
        }
        return copyIdentifier
    }

    /// Opens app-links.json in its default editor, creating it first from
    /// the rules in effect if it doesn't exist. Falls back to showing it in
    /// the Finder. Only ever called from a button click.
    func openAppLinksFile() {
        let store = appLinkRouter.store
        do {
            try store.createFileIfNeeded()
        } catch {
            appLinkSaveError = "Couldn't create \(AppLinkConfigFile.fileName): \(error.localizedDescription)"
            return
        }
        refreshAppLinks()
        if !NSWorkspace.shared.open(store.fileURL) {
            NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
        }
    }

    func testAppLink(_ urlString: String) -> AppLinkMatch {
        return appLinkRouter.test(urlString)
    }

}

// MARK: - Page

/// The App Links page of the Settings window.
struct AppLinksSettingsView: View {

    @ObservedObject var model: SettingsModel

    @State private var selection: String?
    @State private var draft: AppLinkRuleDraft?
    @State private var pendingRemoval: AppLinkRuleDescription?
    @State private var isShowingGallery = false
    @State private var testLink = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matching links open in the app instead of the browser. The first rule that matches wins. Hold ⌥ while opening a link to use the browser.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !model.appLinkIssues.isEmpty {
                AppLinkIssuesView(issues: model.appLinkIssues, fileName: model.appLinksFileURL.lastPathComponent)
            }
            if let error = model.appLinkSaveError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            ruleList
            buttons
            testBox
        }
        .padding(20)
        .sheet(item: $draft) { current in
            AppLinkRuleEditor(draft: current, onCancel: { draft = nil }, onSave: { saved in
                selection = model.saveCustomAppLinkRule(saved)
                draft = nil
            })
        }
        .confirmationDialog(
            "Remove \(pendingRemoval?.rule.name ?? "this rule")?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { description in
            Button("Remove", role: .destructive) {
                model.removeAppLinkRule(identifier: description.rule.id)
                selection = nil
            }
        } message: { description in
            Text(description.isBuiltIn
                 ? "You can add it again from the gallery."
                 : "The rule is deleted from \(model.appLinksFileURL.lastPathComponent).")
        }
    }

    private var selected: AppLinkRuleDescription? {
        return model.appLinkRules.first { $0.id == selection }
    }

    // MARK: Rule list

    private var ruleList: some View {
        List(selection: $selection) {
            ForEach(model.appLinkRules) { description in
                AppLinkRuleRow(description: description,
                               isEditable: model.appLinksAreEditable,
                               isOn: ruleBinding(description.rule.id))
                    .tag(description.id)
                    .contextMenu { contextMenu(for: description) }
            }
            .onMove { source, destination in
                model.moveAppLinkRules(fromOffsets: source, toOffset: destination)
            }
            .moveDisabled(!model.appLinksAreEditable)
        }
        .listStyle(.bordered(alternatesRowBackgrounds: false))
        .frame(minHeight: 150)
        .overlay {
            if model.appLinkRules.isEmpty {
                Text("No rules. Add one with +.")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isShowingGallery) {
            AppLinkGalleryView(rules: model.appLinkGallery,
                               onAdd: { model.addGalleryAppLinkRule(identifier: $0) },
                               onDone: { isShowingGallery = false })
        }
    }

    @ViewBuilder
    private func contextMenu(for description: AppLinkRuleDescription) -> some View {
        Button("Edit…") { edit(description) }
            .disabled(description.isBuiltIn || !model.appLinksAreEditable)
        Button("Duplicate") { duplicate(description) }
            .disabled(!model.appLinksAreEditable)
        Divider()
        Button("Remove…") { pendingRemoval = description }
            .disabled(!model.appLinksAreEditable)
    }

    private func ruleBinding(_ identifier: String) -> Binding<Bool> {
        Binding(
            get: { model.appLinkRules.first { $0.id == identifier }?.rule.isEnabled ?? false },
            set: { model.setAppLinkRule(identifier: identifier, enabled: $0) })
    }

    // MARK: Buttons

    private var selectedIsBuiltIn: Bool {
        return selected?.isBuiltIn ?? true
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Menu {
                Button("Add from Gallery…") { isShowingGallery = true }
                Button("New Custom Rule…") { draft = AppLinkRuleDraft() }
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel("Add Rule")
            }
            .menuStyle(.borderedButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add a rule from the gallery, or write a custom one")
            .disabled(!model.appLinksAreEditable)

            Button {
                pendingRemoval = selected
            } label: {
                // Sized so the button is as tall as the ones beside it.
                Image(systemName: "minus")
                    .frame(width: 14, height: 16)
                    .accessibilityLabel("Remove Rule")
            }
            .help("Remove the selected rule")
            .disabled(selected == nil || !model.appLinksAreEditable)

            Button("Edit…") {
                if let selected = selected { edit(selected) }
            }
            .help(selected?.isBuiltIn == true ? "Built-in rules can't be edited. Duplicate one to make an editable copy." : "Edit the selected custom rule")
            .disabled(selectedIsBuiltIn || !model.appLinksAreEditable)

            Button("Duplicate") {
                if let selected = selected { duplicate(selected) }
            }
            .help("Make an editable custom copy of the selected rule")
            .disabled(selected == nil || !model.appLinksAreEditable)

            Spacer()

            Button("Open Config File") {
                model.openAppLinksFile()
            }
            .help(model.appLinksFileURL.path)
        }
    }

    private func edit(_ description: AppLinkRuleDescription) {
        guard !description.isBuiltIn else {
            return
        }
        draft = AppLinkRuleDraft(rule: description.rule)
    }

    private func duplicate(_ description: AppLinkRuleDescription) {
        if let identifier = model.duplicateAppLinkRule(identifier: description.id) {
            selection = identifier
        }
    }

    // MARK: Test a link

    private var testBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Test a link")
                    .font(.headline)
                TextField("Test a link", text: $testLink, prompt: Text("Paste a link"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
                AppLinkTestResultView(result: testResult)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var testResult: AppLinkTestResult {
        let link = testLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if link.isEmpty {
            return .empty
        }
        switch model.testAppLink(link) {
        case let .app(rule, url):
            return .match(text: "\(rule.name) catches this. It receives", url: url.absoluteString)
        case .browser(unavailable: let rule?):
            let reason = rule.isEnabled ? "its app isn't installed" : "it's off"
            return .browser("Goes to the browser. \(rule.name) matches, but \(reason).")
        case .browser(unavailable: nil):
            return .browser("Goes to the browser. No rule matches.")
        }
    }

}

// MARK: - Pieces

/// One rule in the list: drag handle, icon, name, description, toggle.
struct AppLinkRuleRow: View {

    let description: AppLinkRuleDescription
    let isEditable: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag to change the match order")
            Image(nsImage: description.image)
                .resizable()
                .frame(width: 28, height: 28)
                .saturation(description.isInstalled ? 1 : 0)
                .opacity(description.isInstalled ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(description.rule.name)
                        .foregroundStyle(description.isInstalled ? .primary : .secondary)
                    if !description.isBuiltIn {
                        Text("Custom")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18)))
                    }
                }
                Text(description.isInstalled ? description.summary : "Not installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Toggle(description.rule.name, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!description.isInstalled || !isEditable)
        }
        .padding(.vertical, 3)
    }

}

/// Errors in app-links.json, shown above the list.
struct AppLinkIssuesView: View {

    static let shownLimit = 8

    let issues: [AppLinkConfigIssue]
    let fileName: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("\(fileName) has \(issues.count == 1 ? "an error" : "\(issues.count) errors"). The last good rules are still in use, and the list can't be changed until the file is fixed.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
                ForEach(Array(issues.prefix(Self.shownLimit).enumerated()), id: \.offset) { _, issue in
                    Text(issue.description)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if issues.count > Self.shownLimit {
                    Text("And \(issues.count - Self.shownLimit) more. `app-links check` lists them all.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

enum AppLinkTestResult {
    case empty
    case match(text: String, url: String)
    case browser(String)
    case problem(String)
}

struct AppLinkTestResultView: View {

    let result: AppLinkTestResult

    var body: some View {
        switch result {
        case .empty:
            Text("Shows which rule catches a link and what the app receives. Nothing is opened.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .match(text, url):
            Label {
                (Text(text + " ") + Text(url).font(.system(.callout, design: .monospaced)))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .font(.callout)
        case let .browser(text):
            Label {
                Text(text).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "safari").foregroundStyle(.secondary)
            }
            .font(.callout)
        case let .problem(text):
            Label {
                Text(text).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            }
            .font(.callout)
        }
    }

}

// MARK: - Edit sheet

/// A custom rule being added or edited.
struct AppLinkRuleDraft: Identifiable {
    let id = UUID()
    /// The rule's id when editing, nil when adding. Ids never change.
    var originalIdentifier: String?
    var bundleIdentifier = ""
    var name = ""
    var pattern = ""
    var rewrite = ""

    init() {}

    init(rule: AppLinkRule) {
        originalIdentifier = rule.id
        bundleIdentifier = rule.bundleIdentifier
        name = rule.name
        pattern = rule.pattern
        rewrite = rule.rewriteTemplate ?? ""
    }

    func rule(identifier: String, isEnabled: Bool) -> AppLinkRule {
        return AppLinkRule(
            id: identifier,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bundleIdentifier: bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            pattern: pattern,
            rewriteTemplate: AppLinkConfigParser.normalizedRewrite(rewrite),
            isEnabled: isEnabled)
    }
}

struct AppLinkRuleEditor: View {

    @State var draft: AppLinkRuleDraft
    let onCancel: () -> Void
    let onSave: (AppLinkRuleDraft) -> Void

    @State private var testLink = ""

    private var rule: AppLinkRule {
        return draft.rule(identifier: draft.originalIdentifier ?? "draft", isEnabled: true)
    }

    private var issues: [AppLinkConfigIssue] {
        return AppLinkRuleValidator.issues(for: rule)
    }

    /// Issues worth showing while typing. An empty field just keeps Save
    /// disabled; it doesn't need a message.
    private var visibleIssues: [AppLinkConfigIssue] {
        return issues.filter { !$0.message.hasPrefix("must not be empty") }
    }

    private var app: AppLinkRuleDescription? {
        guard !draft.bundleIdentifier.isEmpty else {
            return nil
        }
        return AppLinkRouter.describe(rule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.originalIdentifier == nil ? "New Rule" : "Edit Rule")
                .font(.headline)

            field("App", footer: "Pick an installed app. The rule is skipped on a Mac that doesn't have it.") {
                HStack {
                    if let app = app {
                        Image(nsImage: SettingsIcon.small(app.image))
                        Text(app.isInstalled ? app.appName : draft.bundleIdentifier)
                        if !app.isInstalled {
                            Text("Not installed").foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No app chosen").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose…", action: chooseApp)
                }
            }

            field("Name") {
                TextField("Name", text: $draft.name, prompt: Text("Example"))
                    .labelsHidden()
            }

            field("Link pattern", footer: "A regular expression, matched against the whole link. Case doesn't matter. Put ( ) around the parts to pass on.") {
                TextField("Link pattern", text: $draft.pattern, prompt: Text("^https://example\\.com/(.+)$"))
                    .labelsHidden()
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
            }

            field("Send to the app as", footer: "$1 to $9 insert the parts the pattern captured. Leave this empty to pass the link through unchanged.") {
                TextField("Send to the app as", text: $draft.rewrite, prompt: Text("example://$1"))
                    .labelsHidden()
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
            }

            if !visibleIssues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(visibleIssues.enumerated()), id: \.offset) { _, issue in
                        Label {
                            Text("\(label(for: issue.field)) \(issue.message)")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        }
                        .font(.callout)
                    }
                }
            }

            Divider()

            field("Test a link") {
                TextField("Test a link", text: $testLink, prompt: Text("Paste a link"))
                    .labelsHidden()
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
            }
            AppLinkTestResultView(result: testResult)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!issues.isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
        .frame(width: 500)
    }

    private func field<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout.weight(.medium))
            content()
            if let footer = footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func label(for field: String?) -> String {
        switch field {
        case "bundleIdentifier": return "App:"
        case "name": return "Name:"
        case "pattern": return "Link pattern"
        case "rewrite": return "Send to the app as"
        default: return "Rule:"
        }
    }

    /// Tests only this rule, as if it were on and its app installed.
    private var testResult: AppLinkTestResult {
        let link = testLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if link.isEmpty {
            return .empty
        }
        if draft.pattern.isEmpty || issues.contains(where: { $0.field == "pattern" || $0.field == "rewrite" }) {
            return .problem("Fix the link pattern and \"Send to the app as\" first.")
        }
        if case let .app(_, url) = AppLinkMatcher.match(link, rules: [rule], isInstalled: { _ in true }) {
            return .match(text: "Matches. The app receives", url: url.absoluteString)
        }
        if rule.patternMatches(link) {
            return .problem("Matches, but \"Send to the app as\" doesn't make a valid URL from it.")
        }
        return .browser("Doesn't match. The link goes to the browser.")
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App"
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            return
        }
        draft.bundleIdentifier = bundleIdentifier
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.name = (url.lastPathComponent as NSString).deletingPathExtension
        }
    }

}
