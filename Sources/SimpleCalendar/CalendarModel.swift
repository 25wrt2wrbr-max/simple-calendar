import AppKit
import Foundation
import SwiftUI

enum WeekStart: String {
    case sunday
    case monday

    var firstWeekday: Int { self == .sunday ? 1 : 2 }
}

struct DayCellModel: Identifiable {
    let id: Int
    let date: Date?
    let dayNumber: Int?
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool
}

struct WeekRowModel: Identifiable {
    let id: Int
    let weekNumber: Int
    let cells: [DayCellModel]
}

@MainActor
final class CalendarModel: ObservableObject {
    static let shared = CalendarModel()

    private enum Key {
        static let weekStart = "weekStart"
        static let showWeekNumbers = "showWeekNumbers"
        static let floatsOnTop = "floatsOnTop"
    }

    @Published private(set) var displayedMonth: Date
    @Published var selectedDate: Date?
    @Published var isJumping = false
    @Published var jumpText = ""
    @Published var isPickerPresented = false

    /// Set when rendering a development snapshot, where AppKit-backed views are skipped.
    var snapshotMode = false

    @Published var weekStart: WeekStart {
        didSet {
            calendar.firstWeekday = weekStart.firstWeekday
            UserDefaults.standard.set(weekStart.rawValue, forKey: Key.weekStart)
        }
    }

    @Published var showWeekNumbers: Bool {
        didSet { UserDefaults.standard.set(showWeekNumbers, forKey: Key.showWeekNumbers) }
    }

    @Published var floatsOnTop: Bool {
        didSet {
            UserDefaults.standard.set(floatsOnTop, forKey: Key.floatsOnTop)
            applyWindowPreferences()
        }
    }

    private var calendar = Calendar.current

    weak var window: NSWindow? {
        didSet {
            guard window !== oldValue else { return }
            applyWindowPreferences()
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedWeekStart = defaults.string(forKey: Key.weekStart).flatMap(WeekStart.init(rawValue:))
        let weekStart = storedWeekStart ?? .sunday

        self.weekStart = weekStart
        self.showWeekNumbers = defaults.bool(forKey: Key.showWeekNumbers)
        self.floatsOnTop = defaults.bool(forKey: Key.floatsOnTop)

        var calendar = Calendar.current
        calendar.firstWeekday = weekStart.firstWeekday
        self.calendar = calendar

        let now = Date()
        self.displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    }

    // MARK: - Display

    var calendarForDisplay: Calendar { calendar }

    var today: Date { calendar.startOfDay(for: Date()) }

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var displayedYear: Int { calendar.component(.year, from: displayedMonth) }
    var displayedMonthNumber: Int { calendar.component(.month, from: displayedMonth) }
    var currentMonthNumber: Int { calendar.component(.month, from: today) }
    var currentYear: Int { calendar.component(.year, from: today) }

    func monthSymbol(_ month: Int) -> String {
        let symbols = calendar.shortMonthSymbols
        guard symbols.indices.contains(month - 1) else { return "" }
        return symbols[month - 1]
    }

    var weekdayLabels: [String] {
        let symbols = calendar.shortWeekdaySymbols
        guard symbols.count == 7 else { return [] }
        let start = calendar.firstWeekday - 1
        return (0..<7).map { offset in
            String(symbols[(start + offset) % 7].prefix(2))
        }
    }

    var weekRows: [WeekRowModel] {
        let firstOfMonth = displayedMonth
        let leading = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [DayCellModel] = []
        cells.reserveCapacity(42)
        for slot in 0..<42 {
            let offset = slot - leading
            guard offset >= 0, offset < daysInMonth,
                  let date = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) else {
                cells.append(DayCellModel(id: slot, date: nil, dayNumber: nil,
                                          isToday: false, isSelected: false, isWeekend: false))
                continue
            }
            cells.append(DayCellModel(
                id: slot,
                date: date,
                dayNumber: calendar.component(.day, from: date),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isSelected: selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                isWeekend: calendar.isDateInWeekend(date)
            ))
        }

        return (0..<6).map { row in
            let rowCells = Array(cells[(row * 7)..<(row * 7 + 7)])
            let rowStart = calendar.date(byAdding: .day, value: row * 7 - leading, to: firstOfMonth) ?? firstOfMonth
            return WeekRowModel(
                id: row,
                weekNumber: calendar.component(.weekOfYear, from: rowStart),
                cells: rowCells
            )
        }
    }

    var footerText: String {
        if let selected = selectedDate {
            var parts = [selected.formatted(shortDateStyle),
                         "wk \(calendar.component(.weekOfYear, from: selected))"]
            if let relative = relativeText(for: selected) { parts.append(relative) }
            return parts.joined(separator: " · ")
        }
        let days = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        let weekRef = calendar.isDate(displayedMonth, equalTo: today, toGranularity: .month) ? today : displayedMonth
        let first = displayedMonth.formatted(shortDateStyle)
        return "\(first) · \(days) days · wk \(calendar.component(.weekOfYear, from: weekRef))"
    }

    private var shortDateStyle: Date.FormatStyle {
        .dateTime.weekday(.abbreviated).day().month(.abbreviated).year()
    }

    private func relativeText(for date: Date) -> String? {
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case 2...370: return "in \(days) days"
        case -370...(-2): return "\(abs(days)) days ago"
        default: return nil
        }
    }

    // MARK: - Navigation

    func stepMonth(_ delta: Int) {
        guard let target = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: target)) ?? target
        selectedDate = nil
    }

    func stepYear(_ delta: Int) { stepMonth(delta * 12) }

    func goToToday() {
        let now = today
        displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        selectedDate = now
    }

    func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        if !calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
        }
    }

    func moveSelection(days: Int) {
        let base = selectedDate ?? today
        guard let target = calendar.date(byAdding: .day, value: days, to: base) else { return }
        select(target)
    }

    func jump(toYear year: Int, month: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let target = calendar.date(from: comps) else { return }
        displayedMonth = target
        selectedDate = nil
    }

    // MARK: - Jump field

    func beginJump(seed: String? = nil) {
        if let seed, isJumping {
            jumpText = seed
        } else if isJumping {
            jumpText = ""
        } else {
            isJumping = true
            jumpText = seed ?? ""
        }
    }

    func cancelJump() {
        isJumping = false
        jumpText = ""
    }

    var jumpResult: JumpParser.Result? {
        let trimmed = jumpText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return JumpParser.parse(trimmed, calendar: calendar, referencing: displayedMonth)
    }

    var jumpIsValid: Bool { jumpResult != nil }

    var jumpPreviewText: String {
        let trimmed = jumpText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "Month, date or year — e.g. jul, 14 mar 2027, 12/25, 2031"
        }
        guard let result = jumpResult else { return "No match for “\(trimmed)”" }
        if let day = result.day {
            return "→ " + day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        }
        return "→ " + result.monthStart.formatted(.dateTime.month(.wide).year())
    }

    func commitJump() {
        guard let result = jumpResult else { return }
        displayedMonth = result.monthStart
        selectedDate = result.day
        cancelJump()
    }

    // MARK: - Window

    func attach(window: NSWindow?) {
        guard let window else { return }
        self.window = window
    }

    private func applyWindowPreferences() {
        guard let window else { return }
        window.level = floatsOnTop ? .floating : .normal
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
    }
}
