import XCTest
@testable import TasksApp

final class TodoItemTests: XCTestCase {
    func testRemainingCountIgnoresFinishedTasks() {
        let items = [
            TodoItem(title: "A"),
            TodoItem(title: "B", done: true),
            TodoItem(title: "C")
        ]
        XCTAssertEqual(items.remainingCount, 2)
    }

    func testAddTaskTrimsAndRejectsBlankTitles() {
        var items: [TodoItem] = []
        XCTAssertFalse(items.addTask(titled: "   "))
        XCTAssertTrue(items.addTask(titled: "  Ship it  "))
        XCTAssertEqual(items.map(\.title), ["Ship it"])
    }

    func testClearFinishedKeepsOpenTasks() {
        var items = [TodoItem(title: "A", done: true), TodoItem(title: "B")]
        items.clearFinished()
        XCTAssertEqual(items.map(\.title), ["B"])
    }
}
