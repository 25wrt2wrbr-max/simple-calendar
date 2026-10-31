import SwiftUI

@main
struct SimpleCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = CalendarModel.shared

    var body: some Scene {
        Window("Simple Calendar", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 332, height: 310)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CalendarCommands(model: model)
        }
    }
}

struct CalendarCommands: Commands {
    @ObservedObject var model: CalendarModel

    var body: some Commands {
        CommandMenu("Calendar") {
            Button("Today") { model.goToToday() }
                .keyboardShortcut("t", modifiers: .command)

            Button("Jump to Date…") { model.beginJump() }
                .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Previous Month") { model.stepMonth(-1) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Month") { model.stepMonth(1) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Previous Year") { model.stepYear(-1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Button("Next Year") { model.stepYear(1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])

            Divider()

            Toggle("Show Week Numbers", isOn: $model.showWeekNumbers)
            Picker("Week Starts On", selection: $model.weekStart) {
                Text("Sunday").tag(WeekStart.sunday)
                Text("Monday").tag(WeekStart.monday)
            }
            Toggle("Keep Window on Top", isOn: $model.floatsOnTop)
        }
    }
}
