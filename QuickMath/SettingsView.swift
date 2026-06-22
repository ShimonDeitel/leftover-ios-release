import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false

    private var theme: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRaw) ?? .system },
            set: { themeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    // MARK: Pro
                    Section("Leftover Pro") {
                        if store.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.qmAccent)
                                Text("You have Pro")
                                    .font(.subheadline.weight(.medium))
                            }
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                Link(destination: url) {
                                    Label("Manage Subscription", systemImage: "arrow.up.right")
                                }
                                .foregroundStyle(Color.qmAccent)
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Label("Unlock Leftover Pro — \(store.displayPrice)/mo", systemImage: "lock.open.fill")
                            }
                            .foregroundStyle(Color.qmAccent)

                            Button {
                                Task { await store.restore() }
                            } label: {
                                Label("Restore Purchases", systemImage: "arrow.clockwise")
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                    }

                    // MARK: Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: theme) {
                            ForEach(AppTheme.allCases) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // MARK: About
                    Section("About") {
                        if let url = URL(string: "https://shimondeitel.github.io/leftover-site/privacy.html") {
                            Link(destination: url) {
                                Label("Privacy Policy", systemImage: "hand.raised.fill")
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            Link(destination: url) {
                                Label("Terms of Use", systemImage: "doc.text")
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                    }

                    // MARK: Data
                    Section("Data") {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all your fridge items, ideas, and history.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(store)
            }
        }
    }
}
