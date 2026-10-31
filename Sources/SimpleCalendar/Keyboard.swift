import Foundation

/// One key press, stripped of AppKit so it can be tested without a window.
struct KeyPress {
    let keyCode: UInt16
    let characters: String
    let shift: Bool
    let hasSystemModifier: Bool
}

enum KeyCommand {
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
    static let escape: UInt16 = 53
}

/// Returns true when the key was consumed.
@MainActor
@discardableResult
func handleKeyPress(_ press: KeyPress, model: CalendarModel) -> Bool {
    guard !press.hasSystemModifier else { return false }

    switch press.keyCode {
    case KeyCommand.left:
        if press.shift { model.moveSelection(days: -1) } else { model.stepMonth(-1) }
        return true
    case KeyCommand.right:
        if press.shift { model.moveSelection(days: 1) } else { model.stepMonth(1) }
        return true
    case KeyCommand.up:
        if press.shift { model.moveSelection(days: -7) } else { model.stepYear(-1) }
        return true
    case KeyCommand.down:
        if press.shift { model.moveSelection(days: 7) } else { model.stepYear(1) }
        return true
    case KeyCommand.escape:
        model.selectedDate = nil
        return true
    default:
        break
    }

    guard let first = press.characters.first else { return false }

    if first == "/" {
        model.beginJump()
        return true
    }

    if first.isNumber {
        model.beginJump(seed: press.characters)
        return true
    }

    guard !press.shift else { return false }

    switch press.characters.lowercased() {
    case "t": model.goToToday(); return true
    case "j", "l": model.stepMonth(1); return true
    case "k", "h": model.stepMonth(-1); return true
    default: return false
    }
}
