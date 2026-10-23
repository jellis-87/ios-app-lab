import SwiftUI

struct ContentView: View {
    @State private var items = [
        TodoItem(title: "Sketch onboarding flow"),
        TodoItem(title: "Write App Store blurb", done: true),
        TodoItem(title: "Test on small screens")
    ]
    @State private var newTitle = ""
    @State private var showClearAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New task", text: $newTitle)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newTitle.isEmpty)
                    }
                }
                Section("\(items.remainingCount) remaining") {
                    ForEach($items) { $item in
                        HStack {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.done ? .green : .gray)
                                .font(.title3)
                            Text(item.title)
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? .secondary : .primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { item.done.toggle() }
                    }
                    .onDelete { offsets in items.remove(atOffsets: offsets) }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { showClearAlert = true }
                }
            }
            .alert("Clear finished tasks?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { items.clearFinished() }
            } message: {
                Text("Swipe left on a row to delete a single task.")
            }
        }
    }

    private func add() {
        if items.addTask(titled: newTitle) {
            newTitle = ""
        }
    }
}

#Preview {
    ContentView()
}
