import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: CalendarModel
    @FocusState private var jumpFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 26)          // room for the traffic lights / drag area
                .overlay {
                    if !model.snapshotMode {
                        WindowDragArea()
                    }
                }

            header

            if model.isJumping {
                JumpBar(focused: $jumpFocused)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            weekdayHeader

            MonthGridView()
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .layoutPriority(1)

            footer
        }
        .frame(minWidth: 300, minHeight: 286)
        .background {
            if !model.snapshotMode {
                WindowAccessor { model.attach(window: $0) }
            }
        }
        .animation(.easeOut(duration: 0.14), value: model.isJumping)
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 2) {
            NavChevron(symbol: "chevron.left", help: "Previous month  ←") { model.stepMonth(-1) }

            Button {
                model.isPickerPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(model.monthTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 146)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Choose a month or year")
            .popover(isPresented: $model.isPickerPresented, arrowEdge: .bottom) {
                MonthYearPicker()
                    .environmentObject(model)
            }

            NavChevron(symbol: "chevron.right", help: "Next month  →") { model.stepMonth(1) }

            Spacer(minLength: 0)

            IconButton(symbol: "magnifyingglass", help: "Jump to a month or date  /") {
                model.beginJump()
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Weekday row

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            if model.showWeekNumbers {
                Text("WK")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18)
            }
            ForEach(model.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 3)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text(model.footerText)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button {
                model.goToToday()
            } label: {
                Text("Today")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Go to today  T")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 7)
    }

    // MARK: - Right click

    @ViewBuilder
    private var contextMenu: some View {
        Button("Today") { model.goToToday() }
        Button("Jump to Date…") { model.beginJump() }
        Divider()
        Button(model.weekStart == .sunday ? "Week Starts on Monday" : "Week Starts on Sunday") {
            model.weekStart = model.weekStart == .sunday ? .monday : .sunday
        }
        Toggle("Show Week Numbers", isOn: $model.showWeekNumbers)
        Toggle("Keep on Top", isOn: $model.floatsOnTop)
    }
}

// MARK: - Small building blocks

struct NavChevron: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @StateObject private var hover = Ref(false)

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hover.value ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(hover.value ? 0.08 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.value = $0 }
        .help(help)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @StateObject private var hover = Ref(false)

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hover.value ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(hover.value ? 0.08 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.value = $0 }
        .help(help)
    }
}

// MARK: - Jump bar

struct JumpBar: View {
    @EnvironmentObject private var model: CalendarModel
    @FocusState.Binding var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                TextField("Month, date or year…", text: $model.jumpText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($focused)
                    .onSubmit { model.commitJump() }

                if !model.jumpText.isEmpty {
                    Button {
                        model.jumpText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09))
            )

            Text(model.jumpPreviewText)
                .font(.system(size: 10))
                .foregroundStyle(model.jumpIsValid ? .secondary : .tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }
}

// MARK: - Month / year picker

struct MonthYearPicker: View {
    @EnvironmentObject private var model: CalendarModel
    @StateObject private var yearBox = Ref(0)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { yearBox.value -= 1 } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(String(yearBox.value))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Button { yearBox.value += 1 } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    let isCurrent = month == model.currentMonthNumber && yearBox.value == model.currentYear
                    Button {
                        model.jump(toYear: yearBox.value, month: month)
                        model.isPickerPresented = false
                    } label: {
                        Text(model.monthSymbol(month))
                            .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isCurrent ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.001))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 186)
        .onAppear { yearBox.value = model.displayedYear }
    }
}
