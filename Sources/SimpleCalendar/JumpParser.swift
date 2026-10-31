import Foundation

/// Turns whatever the user types into a month (and optionally a day).
///
/// Supported shapes, all case-insensitive:
///   jul / july / sept        -> that month, current year
///   july 2027 / 2027 july    -> that month + year
///   2027                     -> same month, different year
///   12                       -> December (months win over day numbers)
///   dec 25 / 25 dec          -> that day
///   2027-03-14 / 14 mar 2027 -> that day
///   12/25 / 25/12            -> that day (handles either order)
///   today / now              -> today
enum JumpParser {
    struct Result {
        let monthStart: Date
        let day: Date?
    }

    static func parse(_ raw: String, calendar: Calendar, referencing reference: Date) -> Result? {
        let normalized = raw
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
        let tokens = normalized.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard !tokens.isEmpty else { return nil }

        let base = startOfMonth(reference, calendar: calendar)
        let baseParts = calendar.dateComponents([.year, .month], from: base)

        var year: Int?
        var month: Int?
        var numbers: [Int] = []

        for token in tokens {
            if token.allSatisfy(\.isNumber) {
                guard let value = Int(token) else { return nil }
                if token.count >= 4 {
                    guard (1...9999).contains(value) else { return nil }
                    year = value
                } else {
                    numbers.append(value)
                }
            } else if let index = monthIndex(for: token, calendar: calendar) {
                month = index
            } else if token == "today" || token == "now" || token == "tod" {
                let today = calendar.startOfDay(for: Date())
                return Result(monthStart: startOfMonth(today, calendar: calendar), day: today)
            } else {
                return nil
            }
        }

        let targetYear = year ?? baseParts.year ?? 1
        var targetMonth = month ?? baseParts.month ?? 1
        var targetDay: Int?

        switch numbers.count {
        case 0:
            break

        case 1:
            let n = numbers[0]
            if month == nil, year == nil {
                // A lone small number reads as a month; larger ones as a day.
                if (1...12).contains(n) {
                    targetMonth = n
                } else if (1...31).contains(n) {
                    targetDay = n
                } else {
                    return nil
                }
            } else if month != nil {
                guard (1...31).contains(n) else { return nil }
                targetDay = n
            } else {
                guard (1...12).contains(n) else { return nil }
                targetMonth = n
            }

        case 2:
            let a = numbers[0]
            let b = numbers[1]
            if (1...12).contains(a), (1...31).contains(b) {
                if month == nil { targetMonth = a }
                targetDay = b
            } else if (1...31).contains(a), (1...12).contains(b) {
                if month == nil { targetMonth = b }
                targetDay = a
            } else {
                return nil
            }

        default:
            return nil
        }

        guard (1...12).contains(targetMonth), (1...9999).contains(targetYear) else { return nil }

        var comps = DateComponents()
        comps.year = targetYear
        comps.month = targetMonth
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps) else { return nil }

        guard var day = targetDay else {
            return Result(monthStart: firstOfMonth, day: nil)
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 28
        day = min(max(day, 1), daysInMonth)
        guard let resolved = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { return nil }
        return Result(monthStart: firstOfMonth, day: resolved)
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private static func monthIndex(for token: String, calendar: Calendar) -> Int? {
        let full = calendar.monthSymbols.map { $0.lowercased() }
        let short = calendar.shortMonthSymbols.map { $0.lowercased() }

        if let index = full.firstIndex(of: token) { return index + 1 }
        if let index = short.firstIndex(of: token) { return index + 1 }

        guard token.count >= 2 else { return nil }
        var matches = Set<Int>()
        for (index, name) in full.enumerated() where name.hasPrefix(token) { matches.insert(index + 1) }
        for (index, name) in short.enumerated() where name.hasPrefix(token) { matches.insert(index + 1) }
        // "sept" -> "sep", "junee"? keep the reverse check narrow.
        for (index, name) in short.enumerated() where token.hasPrefix(name) && token.count <= name.count + 2 {
            matches.insert(index + 1)
        }
        return matches.count == 1 ? matches.first : nil
    }
}
