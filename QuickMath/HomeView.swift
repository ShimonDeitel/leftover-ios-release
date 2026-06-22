import SwiftUI
import SwiftData

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showInsights = false
    @State private var showAddItem = false

    var body: some View {
        ZStack {
            QMBackground()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Urgency summary tiles
                        HStack(spacing: 12) {
                            MetricTile(value: "\(appModel.activeItems.count)", label: "Open Items")
                            MetricTile(value: "\(urgentCount)", label: "Use Today")
                            MetricTile(value: "\(appModel.usedCount)", label: "Rescued")
                        }
                        .padding(.horizontal, 16)

                        // Primary action — fridge list
                        GridView()

                        // Pro tile — daily ideas / insights
                        Button {
                            Haptics.tap()
                            if store.isPro { showInsights = true } else { showPaywall = true }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.isPro ? "Waste Saved" : "Leftover Pro")
                                        .font(.headline.weight(.semibold))
                                    Text(store.isPro
                                         ? "\(appModel.savedThisWeek) items rescued this week"
                                         : "More ideas, reminders & waste stats")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: store.isPro ? "chart.bar.fill" : "lock.fill")
                                    .foregroundStyle(Color.qmAccent)
                                    .font(.title3)
                            }
                        }
                        .qmCard()
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .navigationTitle("Leftover")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color.qmAccent)
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showAddItem = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.qmAccent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store).environmentObject(appModel) }
        .sheet(isPresented: $showPaywall)  { PaywallView().environmentObject(store) }
        .sheet(isPresented: $showInsights) { InsightsView().environmentObject(appModel).environmentObject(store) }
        .sheet(isPresented: $showAddItem)  { AddItemSheet().environmentObject(appModel) }
        .onAppear {
            if forceScreen == "paywall"  { showPaywall = true }
            if forceScreen == "insights" { showInsights = true }
            if forceScreen == "settings" { showSettings = true }
        }
    }

    private var urgentCount: Int {
        appModel.activeItems.filter { $0.urgencyLevel == .expired || $0.urgencyLevel == .urgent }.count
    }
}

// MARK: - Add Item Sheet

struct AddItemSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var hasDate = false
    @State private var useByDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                Form {
                    Section("Item Name") {
                        TextField("e.g. Milk, Leftover pasta", text: $name)
                    }
                    Section {
                        Toggle("Set use-by date", isOn: $hasDate)
                        if hasDate {
                            DatePicker("Use by", selection: $useByDate, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        appModel.addItem(name: trimmed, useByDate: hasDate ? useByDate : nil)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
