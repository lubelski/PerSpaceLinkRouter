//
//  SettingsWindow.swift
//  PerSpaceLinkRouter
//

import AppKit
import SwiftUI

/// The pages of the Settings window, in sidebar order. A new page gets a
/// case here and its view in `SettingsRootView.page`.
enum SettingsSection: String, CaseIterable, Identifiable {
    // The raw values are kept in UserDefaults, so never rename one.
    case general
    case appLinks
    case permissions
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appLinks: return "App Links"
        case .permissions: return "Permissions"
        case .updates: return "Updates"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .appLinks: return "link"
        case .permissions: return "lock.shield"
        case .updates: return "arrow.down.circle"
        }
    }
}

/// Which page is showing. It is kept in UserDefaults, so the window reopens
/// where it was left.
final class SettingsNavigation: ObservableObject {
    static let key = "SettingsSelectedSection"

    @Published var section: SettingsSection {
        didSet {
            defaults.set(section.rawValue, forKey: Self.key)
            didChange?(section)
        }
    }

    /// Called after the page changes, so the window can title itself with it.
    var didChange: ((SettingsSection) -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        section = defaults.string(forKey: Self.key).flatMap(SettingsSection.init(rawValue:)) ?? .general
    }
}

/// The window's content: a sidebar of pages and the selected page beside it.
struct SettingsRootView: View {
    /// The sidebar's width. It is fixed: the sidebar cannot be dragged wider
    /// or collapsed.
    static let sidebarWidth: CGFloat = 200

    @ObservedObject var model: SettingsModel
    @ObservedObject var updater: AppUpdater
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        // A plain row rather than a split view, so the sidebar keeps its
        // width: it cannot be dragged or collapsed, and there is no sidebar
        // button.
        HStack(spacing: 0) {
            List(selection: Binding<SettingsSection?>(
                get: { navigation.section },
                set: { if let section = $0 { navigation.section = section } }
            )) {
                ForEach(SettingsSection.allCases) { section in
                    // The sidebar draws the selected row's title in a heavier
                    // weight, which widens it. A weight set on the title's own
                    // Text keeps one weight across hover and selection.
                    Label {
                        Text(section.title).fontWeight(.regular)
                    } icon: {
                        Image(systemName: section.symbolName)
                    }
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
            .frame(width: Self.sidebarWidth)
            Divider()
            page
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Catches returning from System Settings after changing a grant.
            model.refresh()
        }
    }

    @ViewBuilder
    private var page: some View {
        switch navigation.section {
        case .general:
            GeneralSettingsView(model: model)
        case .appLinks:
            AppLinksSettingsView(model: model)
        case .permissions:
            PermissionsSettingsView(model: model)
        case .updates:
            UpdatesSettingsView(updater: updater)
        }
    }
}

/// The Settings window: a SwiftUI sidebar and page hosted in an AppKit
/// window. The app has no SwiftUI `App`, so it cannot use the `Settings`
/// scene. The window keeps one size whichever page is showing, and its title
/// names the page.
final class SettingsWindowController: NSWindowController {
    static let defaultSize = NSSize(width: 780, height: 560)
    static let minimumSize = NSSize(width: 640, height: 420)
    static let frameName = "SettingsWindow"

    let navigation: SettingsNavigation

    init(model: SettingsModel, updater: AppUpdater, defaults: UserDefaults = .standard) {
        navigation = SettingsNavigation(defaults: defaults)
        let root = SettingsRootView(model: model, updater: updater, navigation: navigation)
        let hosting = NSHostingController(rootView: root)
        // The window keeps its own size, so switching pages never resizes it.
        hosting.sizingOptions = []

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.contentViewController = hosting
        window.setContentSize(Self.defaultSize)
        window.contentMinSize = Self.minimumSize
        window.collectionBehavior = [.fullScreenNone]
        window.isReleasedWhenClosed = false
        super.init(window: window)

        showTitle(of: navigation.section)
        navigation.didChange = { [weak self] in self?.showTitle(of: $0) }
        if !window.setFrameUsingName(Self.frameName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func showTitle(of section: SettingsSection) {
        window?.title = section.title
    }
}
