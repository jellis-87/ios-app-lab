import Foundation

struct TodoItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var done = false
}

extension Array where Element == TodoItem {
    var remainingCount: Int { filter { !$0.done }.count }

    /// Appends a task unless the title is blank. Returns whether one was added.
    @discardableResult
    mutating func addTask(titled title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        append(TodoItem(title: trimmed))
        return true
    }

    mutating func clearFinished() {
        removeAll { $0.done }
    }
}
