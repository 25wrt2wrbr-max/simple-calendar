// Logic checks for the calendar model and jump parser.
// Run with: ./test.sh
import AppKit
import Foundation

@main
struct TestRunner {
    @MainActor
    static func main() {
        var failures = 0

        func check(_ label: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
            if condition {
                print("  ok   \(label)")
            } else {
                failures += 1
                print("  FAIL \(label) \(detail())")
            }
        }

        let model = CalendarModel.shared
        let calendar = model.calendarForDisplay

        print("Jump parser")
        func parse(_ text: String) -> JumpParser.Result? {
            JumpParser.parse(text, calendar: calendar, referencing: model.displayedMonth)
        }
        func day(_ text: String) -> String? {
            guard let result = parse(text) else { return nil }
            return key(result.day ?? result.monthStart)
        }

        func key(_ date: Date) -> String {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }

        check("'jul' keeps year", day("jul") == "2026-07-01", "got \(day("jul") ?? "nil")")
        check("'mar 2027'", day("mar 2027") == "2027-03-01", "got \(day("mar 2027") ?? "nil")")
        check("'2027 mar'", day("2027 mar") == "2027-03-01", "got \(day("2027 mar") ?? "nil")")
        check("'sept' resolves", day("sept") == "2026-09-01", "got \(day("sept") ?? "nil")")
        check("'2027-03-14'", day("2027-03-14") == "2027-03-14", "got \(day("2027-03-14") ?? "nil")")
        check("'12/25' is Dec 25", day("12/25") == "2026-12-25", "got \(day("12/25") ?? "nil")")
        check("'25/12' is Dec 25", day("25/12") == "2026-12-25", "got \(day("25/12") ?? "nil")")
        check("'14 mar'", day("14 mar") == "2026-03-14", "got \(day("14 mar") ?? "nil")")
        check("'2031' keeps month", day("2031") == "2031-10-01", "got \(day("2031") ?? "nil")")
        check("'12' means December", day("12") == "2026-12-01", "got \(day("12") ?? "nil")")
        check("'28' means day 28", day("28") == "2026-10-28", "got \(day("28") ?? "nil")")
        check("'feb 30' clamps", day("feb 30") == "2026-02-28", "got \(day("feb 30") ?? "nil")")
        check("'ju' is ambiguous -> nil", parse("ju") == nil)
        check("gibberish -> nil", parse("banana") == nil)
        check("empty -> nil", parse("   ") == nil)
        check("'today' works", parse("today")?.day.map { calendar.isDateInToday($0) } == true)

        print("Month grid")
        model.jump(toYear: 2026, month: 10)
        let rows = model.weekRows
        check("6 rows", rows.count == 6)
        check("42 cells", rows.reduce(0) { $0 + $1.cells.count } == 42)
        for (index, row) in rows.enumerated() {
            print("       row \(index): " + row.cells.map { $0.dayNumber.map(String.init) ?? "·" }.joined(separator: " "))
        }
        let firstNumbered = rows.flatMap(\.cells).first { $0.dayNumber != nil }
        check("Oct 1 2026 sits in the Thursday column (Sunday start)",
              firstNumbered?.dayNumber == 1 && rows[0].cells[4].dayNumber == 1,
              "got \(String(describing: firstNumbered?.dayNumber)) at index \(String(describing: rows[0].cells.firstIndex { $0.dayNumber == 1 }))")
        let allCells = rows.flatMap(\.cells)
        let thirtyFirst = allCells.first { $0.dayNumber == 31 }
        check("Oct 31 2026 is highlighted as today", thirtyFirst?.isToday == true)
        check("Oct 31 2026 is in the Saturday column", rows.contains { $0.cells[6].dayNumber == 31 },
              "row 4 col 6 = \(String(describing: rows[4].cells[6].dayNumber))")
        check("31 days of October present", allCells.compactMap(\.dayNumber).count == 31)
        check("week numbers ascend by 1", zip(rows, rows.dropFirst()).allSatisfy { $1.weekNumber == $0.weekNumber + 1 })
        check("footer mentions October", model.footerText.contains("Oct 1, 2026"), model.footerText)

        print("Monday-start week")
        model.weekStart = .monday
        model.jump(toYear: 2026, month: 10)
        check("Oct 1 2026 sits in the Thursday column (Monday start)",
              model.weekRows[0].cells[3].dayNumber == 1,
              "got \(String(describing: model.weekRows[0].cells[3].dayNumber))")
        check("weekday labels start with Mo", model.weekdayLabels.first == "Mo", model.weekdayLabels.joined(separator: ","))
        model.weekStart = .sunday

        print("Navigation")
        model.jump(toYear: 2026, month: 1)
        model.stepMonth(-1)
        check("January -> December", model.monthTitle.contains("December 2025"), model.monthTitle)
        model.stepYear(1)
        check("year step", model.monthTitle.contains("December 2026"), model.monthTitle)
        model.goToToday()
        check("today resets to October 2026", model.monthTitle.contains("October 2026"), model.monthTitle)
        check("selecting a day clears month drift", { model.select(model.today); return model.selectedDate != nil }())

        print("Footer with selection")
        check("shows 'today'", model.footerText.contains("today"), model.footerText)

        print("Keyboard")
        func press(_ code: UInt16, _ characters: String = "", shift: Bool = false, system: Bool = false) -> Bool {
            handleKeyPress(KeyPress(keyCode: code, characters: characters, shift: shift, hasSystemModifier: system), model: model)
        }

        model.goToToday()
        model.selectedDate = nil
        let startMonth = model.monthTitle
        check("right arrow is consumed", press(KeyCommand.right))
        check("right arrow advances a month", model.monthTitle != startMonth && model.monthTitle.contains("November 2026"), model.monthTitle)
        check("left arrow goes back", press(KeyCommand.left) && model.monthTitle == startMonth, model.monthTitle)
        check("up arrow changes the year", press(KeyCommand.up) && model.monthTitle.contains("2025"), model.monthTitle)
        check("down arrow returns", press(KeyCommand.down) && model.monthTitle.contains("2026"), model.monthTitle)

        check("shift+right selects a day", press(KeyCommand.right, shift: true) && model.selectedDate != nil)
        let firstSelection = model.selectedDate
        press(KeyCommand.right, shift: true)
        let dayDelta = calendar.dateComponents([.day], from: firstSelection ?? Date(), to: model.selectedDate ?? Date()).day
        check("shift+right moves one day", dayDelta == 1, "delta \(String(describing: dayDelta))")

        check("escape clears the selection", press(KeyCommand.escape) && model.selectedDate == nil)

        check("'t' returns to today", !press(KeyCommand.right) == false && { press(UInt16(0), "t"); return model.monthTitle.contains("October 2026") }(), model.monthTitle)
        check("'t' selects today", model.selectedDate.map { calendar.isDateInToday($0) } == true)

        model.cancelJump()
        check("'/' opens the jump field", press(UInt16(0), "/") && model.isJumping && model.jumpText.isEmpty)
        model.cancelJump()
        check("digits seed the jump field", press(UInt16(0), "7") && model.isJumping && model.jumpText == "7")
        model.cancelJump()
        check("bare 'q' is ignored", press(UInt16(0), "q") == false)
        check("modified keys are ignored", press(KeyCommand.right, system: true) == false)

        print("")
        if failures == 0 {
            print("All checks passed.")
        } else {
            print("\(failures) check(s) failed.")
            exit(1)
        }
    }
}
