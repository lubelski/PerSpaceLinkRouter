//
//  AppLinkGalleryView.swift
//  PerSpaceLinkRouter
//
//  The gallery sheet on the App Links page: the built-in rules that are not
//  in the list, each with an Add button.
//

import AppKit
import SwiftUI

struct AppLinkGalleryView: View {

    /// The built-in rules not in the list. A rule leaves this once added.
    let rules: [AppLinkRuleDescription]
    let onAdd: (String) -> Void
    let onDone: () -> Void

    @State private var search = ""

    private var shown: [AppLinkRuleDescription] {
        let query = search.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return rules
        }
        return rules.filter {
            $0.rule.name.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add from Gallery")
                .font(.headline)
            Text("Ready-made rules. A rule you add goes to the end of your list, turned on.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Search", text: $search, prompt: Text("Search"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            List {
                ForEach(shown) { description in
                    AppLinkGalleryRow(description: description) {
                        onAdd(description.id)
                    }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .frame(height: 330)
            .overlay {
                if shown.isEmpty {
                    Text(rules.isEmpty ? "Every gallery rule is already in your list." : "No rules match the search.")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

}

/// One gallery rule: icon, name, what it matches, and Add.
struct AppLinkGalleryRow: View {

    let description: AppLinkRuleDescription
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: description.image)
                .resizable()
                .frame(width: 28, height: 28)
                .saturation(description.isInstalled ? 1 : 0)
                .opacity(description.isInstalled ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(description.rule.name)
                        .foregroundStyle(description.isInstalled ? .primary : .secondary)
                    if !description.isInstalled {
                        Text("Not installed")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18)))
                    }
                }
                Text(description.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Button("Add", action: onAdd)
                .accessibilityLabel("Add \(description.rule.name)")
        }
        .padding(.vertical, 3)
    }

}
