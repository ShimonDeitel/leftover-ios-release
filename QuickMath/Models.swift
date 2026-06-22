import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class FridgeItem {
    var id: UUID
    var name: String
    var openedDate: Date
    var useByDate: Date?
    var status: String   // "active" | "used" | "wasted"

    init(name: String, openedDate: Date = .now, useByDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.openedDate = openedDate
        self.useByDate = useByDate
        self.status = "active"
    }

    /// Days until use-by. Negative = past. Nil if no date.
    var daysLeft: Int? {
        guard let d = useByDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: d).day
    }

    var urgencyLevel: UrgencyLevel {
        guard let days = daysLeft else { return .low }
        if days < 0  { return .expired }
        if days == 0 { return .urgent }
        if days <= 2 { return .soon }
        return .low
    }
}

enum UrgencyLevel: Int, Comparable {
    case expired = 0, urgent = 1, soon = 2, low = 3
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

@Model
final class UseIdea {
    var id: UUID
    var title: String
    var ingredients: [String]
    var steps: [String]
    var createdDate: Date
    var fridgeItemNames: [String]   // snapshot of item names used

    init(title: String, ingredients: [String], steps: [String], fridgeItemNames: [String]) {
        self.id = UUID()
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.createdDate = .now
        self.fridgeItemNames = fridgeItemNames
    }
}

@Model
final class SaveLog {
    var id: UUID
    var fridgeItemId: UUID
    var fridgeItemName: String
    var action: String   // "used" | "wasted"
    var date: Date

    init(fridgeItemId: UUID, fridgeItemName: String, action: String) {
        self.id = UUID()
        self.fridgeItemId = fridgeItemId
        self.fridgeItemName = fridgeItemName
        self.action = action
        self.date = .now
    }
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var items: [FridgeItem] = []
    @Published private(set) var todayIdea: UseIdea?
    @Published private(set) var logs: [SaveLog] = []
    @Published private(set) var lastGeneratedDate: Date?

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([FridgeItem.self, UseIdea.self, SaveLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback])) ??
                (try! ModelContainer(for: schema))
        }
    }

    func reload() {
        let itemDesc = FetchDescriptor<FridgeItem>(sortBy: [SortDescriptor(\.openedDate, order: .reverse)])
        let ideaDesc = FetchDescriptor<UseIdea>(sortBy: [SortDescriptor(\.createdDate, order: .reverse)])
        let logDesc  = FetchDescriptor<SaveLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        items     = (try? context.fetch(itemDesc)) ?? []
        let ideas = (try? context.fetch(ideaDesc)) ?? []
        logs      = (try? context.fetch(logDesc))  ?? []

        // Today's idea = most recent one generated on today's calendar day
        let cal = Calendar.current
        todayIdea = ideas.first { cal.isDateInToday($0.createdDate) }
        lastGeneratedDate = ideas.first?.createdDate
    }

    func refresh() { reload() }

    // MARK: - Fridge management

    func addItem(name: String, useByDate: Date?) {
        let item = FridgeItem(name: name, openedDate: .now, useByDate: useByDate)
        context.insert(item)
        save()
        Haptics.tap()
    }

    func markItem(_ item: FridgeItem, action: String) {
        let log = SaveLog(fridgeItemId: item.id, fridgeItemName: item.name, action: action)
        context.insert(log)
        item.status = action
        save()
        Haptics.success()
    }

    func deleteItem(_ item: FridgeItem) {
        context.delete(item)
        save()
    }

    // MARK: - Idea generation

    /// Active (non-resolved) fridge items sorted by urgency
    var activeItems: [FridgeItem] {
        items.filter { $0.status == "active" }
             .sorted { $0.urgencyLevel < $1.urgencyLevel }
    }

    /// Generate one use-it-up idea from the most urgent active items.
    func generateIdea() {
        let targets = Array(activeItems.prefix(3))
        guard !targets.isEmpty else { return }

        let names = targets.map { $0.name }
        let idea = UseIdea(
            title: ideaTitle(for: names),
            ingredients: ideaIngredients(for: names),
            steps: ideaSteps(for: names),
            fridgeItemNames: names
        )
        context.insert(idea)
        save()
        Haptics.success()
    }

    // MARK: - Simple deterministic idea builder (no backend)

    private func ideaTitle(for names: [String]) -> String {
        switch names.count {
        case 1: return "Quick \(names[0].capitalized) stir-fry"
        case 2: return "\(names[0].capitalized) & \(names[1].capitalized) scramble"
        default: return "\(names[0].capitalized), \(names[1].capitalized) & \(names[2].capitalized) bowl"
        }
    }

    private func ideaIngredients(for names: [String]) -> [String] {
        var list = names.map { $0.capitalized }
        list += ["Olive oil", "Salt & pepper", "Garlic (optional)"]
        return list
    }

    private func ideaSteps(for names: [String]) -> [String] {
        [
            "Heat a splash of olive oil in a pan over medium-high heat.",
            "Add \(names.joined(separator: " and ")) and cook 3–4 minutes until warmed through.",
            "Season with salt, pepper, and garlic if using.",
            "Serve immediately — enjoy before it goes to waste!"
        ]
    }

    // MARK: - Pro stats

    var usedCount: Int  { logs.filter { $0.action == "used" }.count }
    var wastedCount: Int { logs.filter { $0.action == "wasted" }.count }
    var savedThisWeek: Int {
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now) ?? .now
        return logs.filter { $0.action == "used" && $0.date >= cutoff }.count
    }

    // MARK: - Delete all

    func deleteAllData() {
        items.forEach { context.delete($0) }
        logs.forEach  { context.delete($0) }
        let ideaDesc = FetchDescriptor<UseIdea>()
        let ideas = (try? context.fetch(ideaDesc)) ?? []
        ideas.forEach { context.delete($0) }
        save()
    }

    private func save() {
        try? context.save()
        reload()
    }
}
