import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    private let benefits: [(String, String)] = [
        ("Multiple daily use-it-up ideas instead of just one",
         "lightbulb.fill"),
        ("Waste-saved tally showing items rescued over weeks and months",
         "chart.bar.fill"),
        ("Use-by reminders before open items spoil",
         "bell.badge.fill")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(spacing: 0) {
                    Spacer()

                    // Icon / header
                    VStack(spacing: 12) {
                        Image(systemName: "refrigerator.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.qmAccent)
                        Text("Leftover Pro")
                            .font(.largeTitle.weight(.bold))
                        Text("$0.99 / month. Auto-renews until you cancel.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 32)

                    // Benefits
                    VStack(spacing: 14) {
                        ForEach(benefits, id: \.0) { benefit, icon in
                            HStack(spacing: 14) {
                                Image(systemName: icon)
                                    .foregroundStyle(Color.qmAccent)
                                    .frame(width: 28)
                                Text(benefit)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.vertical, 24)
                    .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)

                    Spacer()

                    // CTA
                    VStack(spacing: 14) {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            HStack {
                                if store.purchaseInFlight {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Unlock for \(store.displayPrice)/mo")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .prominentButton()
                        .disabled(store.purchaseInFlight)
                        .padding(.horizontal, 20)

                        Button {
                            Task { await store.restore() }
                        } label: {
                            Text("Restore Purchases")
                        }
                        .softButton()

                        // Auto-renew disclosure
                        Text("Subscription automatically renews at \(store.displayPrice)/month unless cancelled at least 24 hours before the end of the current period. You can manage or cancel subscriptions in your App Store account settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        HStack(spacing: 16) {
                            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/leftover-site/privacy.html")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.qmAccent)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: store.isPro) { _, newValue in
            if newValue { dismiss() }
        }
    }
}
