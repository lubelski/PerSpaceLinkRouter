//
//  AppLinksSettingsView.swift
//  PerSpaceLinkRouter
//

import SwiftUI

/// The App Links page of the Settings window: a toggle for each built-in
/// rule whose app is installed. It has the whole page, so it can grow into a
/// rule list without changing the window around it.
struct AppLinksSettingsView: View {

    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                if model.appLinkRules.isEmpty {
                    SettingsStatus.text("No supported apps installed")
                }
                ForEach(model.appLinkRules, id: \.rule.id) { description in
                    Toggle(isOn: ruleBinding(description.rule.id)) {
                        HStack {
                            Image(nsImage: SettingsIcon.small(description.image))
                            Text(description.rule.name)
                        }
                    }
                }
            } footer: {
                SettingsFooter("Matching links open in the app instead of the browser. Hold ⌥ while opening a link to use the browser.")
            }
        }
        .formStyle(.grouped)
    }

    private func ruleBinding(_ identifier: String) -> Binding<Bool> {
        Binding(
            get: { model.appLinkRules.first { $0.rule.id == identifier }?.rule.isEnabled ?? false },
            set: { model.setAppLinkRule(identifier: identifier, enabled: $0) })
    }

}
