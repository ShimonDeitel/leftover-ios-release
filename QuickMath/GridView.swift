import SwiftUI
import SwiftData

/// The primary screen: lists open fridge items sorted by urgency,
/// and shows today's "use it up" idea at the bottom.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAddItem = false
    @State private var showPaywall = false
    @State private var showIdeaDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Section header
            HStack {
                Text("Open in Your Fridge")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(appModel.activeItems.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if appModel.activeItems.isEmpty {
                emptyState
            } else {
                itemList
            }

            Divider()
                .padding(.vertical, 12)

            // Today's idea section
            ideaSection
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "refrigerator")
                .font(.system(size: 44))
                .foregroundStyle(Color.qmAccent.opacity(0.6))
            Text("Nothing open yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add an open item from your fridge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .qmCard()
        .padding(.horizontal, 16)
    }

    // MARK: - Item list

    private var itemList: some View {
        VStack(spacing: 8) {
            ForEach(appModel.activeItems) { item in
                FridgeItemRow(item: item)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Today's idea

    private var ideaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Use It Tonight")
                    .font(.headline.weight(.semibold))
                Spacer()
                if store.isPro {
                    // Pro: can regenerate
                    Button {
                        Haptics.tap()
                        appModel.generateIdea()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundStyle(Color.qmAccent)
                    }
                }
            }
            .padding(.horizontal, 16)

            if let idea = appModel.todayIdea {
                Button {
                    showIdeaDetail = true
                    Haptics.tap()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(idea.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(idea.fridgeItemNames.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .qmCard()
                .padding(.horizontal, 16)
            } else {
                // Generate idea button — one per day for free
                VStack(spacing: 8) {
                    if appModel.activeItems.isEmpty {
                        Text("Add fridge items above to get an idea.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    } else {
                        Button {
                            Haptics.tap()
                            appModel.generateIdea()
                        } label: {
                            Text("Get Today's Idea")
                        }
                        .prominentButton()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            }
        }
        .sheet(isPresented: $showIdeaDetail) {
            if let idea = appModel.todayIdea {
                IdeaDetailView(idea: idea)
                    .environmentObject(appModel)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(store)
        }
    }
}

// MARK: - Fridge Item Row

struct FridgeItemRow: View {
    @EnvironmentObject var appModel: AppModel
    let item: FridgeItem

    var body: some View {
        HStack(spacing: 12) {
            // Urgency dot
            Circle()
                .fill(urgencyColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.capitalized)
                    .font(.subheadline.weight(.medium))
                if let days = item.daysLeft {
                    Text(daysLabel(days))
                        .font(.caption)
                        .foregroundStyle(urgencyColor)
                } else {
                    Text("Opened \(item.openedDate, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Quick actions
            Button {
                appModel.markItem(item, action: "used")
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color.qmCorrect)
            }

            Button {
                appModel.markItem(item, action: "wasted")
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(Color.qmWrong)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                appModel.deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var urgencyColor: Color {
        switch item.urgencyLevel {
        case .expired: return Color.qmWrong
        case .urgent:  return Color(hex: "#FF9500")  // orange
        case .soon:    return Color(hex: "#FFCC00")  // yellow
        case .low:     return Color.qmCorrect
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days < 0  { return "Expired \(-days)d ago" }
        if days == 0 { return "Use today!" }
        if days == 1 { return "Use by tomorrow" }
        return "Use within \(days) days"
    }
}

// MARK: - Idea Detail

struct IdeaDetailView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) var dismiss
    let idea: UseIdea

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        Text(idea.title)
                            .font(.title2.weight(.bold))
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingredients").font(.headline).padding(.horizontal, 16)
                            ForEach(idea.ingredients, id: \.self) { ingredient in
                                HStack(spacing: 8) {
                                    Circle().fill(Color.qmAccent).frame(width: 6, height: 6)
                                    Text(ingredient).font(.subheadline)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Steps").font(.headline).padding(.horizontal, 16)
                            ForEach(Array(idea.steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(idx + 1)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.qmAccent)
                                        .frame(width: 22)
                                    Text(step).font(.subheadline)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Mark items used
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mark as used?").font(.headline).padding(.horizontal, 16)
                            ForEach(appModel.activeItems.filter { idea.fridgeItemNames.contains($0.name) }) { item in
                                Button {
                                    appModel.markItem(item, action: "used")
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.qmCorrect)
                                        Text("Mark \(item.name.capitalized) as used")
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Tonight's Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
