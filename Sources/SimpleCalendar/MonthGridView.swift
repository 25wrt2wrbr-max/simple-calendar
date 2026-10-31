import SwiftUI

struct MonthGridView: View {
    @EnvironmentObject private var model: CalendarModel

    private let spacing: CGFloat = 2

    private var visibleRows: [WeekRowModel] {
        let rows = model.weekRows
        let used = rows.filter { row in row.cells.contains { $0.date != nil } }
        return used.isEmpty ? rows : used
    }

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(visibleRows.count)
            let rowHeight = max(24, (geo.size.height - (count - 1) * spacing) / count)
            VStack(spacing: spacing) {
                ForEach(visibleRows) { row in
                    HStack(spacing: spacing) {
                        if model.showWeekNumbers {
                            Text(String(format: "%02d", row.weekNumber))
                                .font(.system(size: 8.5))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .frame(width: 18)
                                .frame(height: rowHeight)
                        }
                        ForEach(row.cells) { cell in
                            DayCell(cell: cell, height: rowHeight)
                        }
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    @EnvironmentObject private var model: CalendarModel
    let cell: DayCellModel
    let height: CGFloat

    @StateObject private var hover = Ref(false)

    var body: some View {
        Button {
            if let date = cell.date { model.select(date) }
        } label: {
            ZStack {
                if cell.isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: badgeSize, height: badgeSize)
                } else if hover.value, cell.date != nil {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: badgeSize, height: badgeSize)
                }

                if cell.isSelected && !cell.isToday {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.4)
                        .frame(width: badgeSize, height: badgeSize)
                }

                Text(cell.dayNumber.map(String.init) ?? "")
                    .font(.system(size: 12.5, weight: cell.isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.date == nil)
        .onHover { hover.value = $0 && cell.date != nil }
    }

    private var badgeSize: CGFloat {
        min(max(height - 8, 22), 30)
    }

    private var numberColor: Color {
        if cell.isToday { return .white }
        if cell.date == nil { return .clear }
        return cell.isWeekend ? Color.primary.opacity(0.55) : Color.primary
    }
}
