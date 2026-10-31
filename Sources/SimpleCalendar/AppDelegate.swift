import AppKit
import SwiftUI

/// Connects a SwiftUI view to its NSWindow so the model can tweak the window.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}

/// Lets the strip at the top of the window move it, since the title bar is hidden.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class DragView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.performZoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }

    override var mouseDownCanMoveWindow: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    private var scrollMonitor: Any?

    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var lastStep: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let model = CalendarModel.shared

        if let snapshotPath = Self.argumentValue(for: "--snapshot") {
            if CommandLine.arguments.contains("--weeks") {
                model.showWeekNumbers = true
            }
            if CommandLine.arguments.contains("--monday") {
                model.weekStart = .monday
            }
            if let month = Self.argumentValue(for: "--month") {
                let parts = month.split(separator: "-")
                if parts.count == 2, let year = Int(parts[0]), let number = Int(parts[1]) {
                    model.jump(toYear: year, month: number)
                }
            }
            if let jump = Self.argumentValue(for: "--jump") {
                model.beginJump(seed: jump)
            }
            renderSnapshot(to: snapshotPath)
            NSApp.terminate(nil)
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event, model: model)
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handleScroll(event, model: model)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Snapshot (development aid: `--snapshot out.png`)

    private static func argumentValue(for flag: String) -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), args.index(after: index) < args.endIndex else { return nil }
        return args[args.index(after: index)]
    }

    private func renderSnapshot(to path: String) {
        let size = NSSize(width: 332, height: 310)
        let model = CalendarModel.shared
        model.snapshotMode = true
        let content = ContentView()
            .environmentObject(model)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("snapshot failed\n".data(using: .utf8)!)
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first?.makeKeyAndOrderFront(nil) }
        return true
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent, model: CalendarModel) -> NSEvent? {
        guard let window = model.window, event.window === window else { return event }

        let isEditingText = (window.firstResponder as? NSTextView)?.isFieldEditor == true
        if isEditingText {
            if event.keyCode == KeyCommand.escape {   // esc closes the jump field
                model.cancelJump()
                window.makeFirstResponder(nil)
                return nil
            }
            return event
        }

        let press = KeyPress(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers ?? "",
            shift: event.modifierFlags.contains(.shift),
            hasSystemModifier: !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        )
        return handleKeyPress(press, model: model) ? nil : event
    }

    // MARK: - Trackpad / wheel

    private func handleScroll(_ event: NSEvent, model: CalendarModel) -> NSEvent? {
        guard let window = model.window, event.window === window, !model.isJumping else { return event }

        let now = ProcessInfo.processInfo.systemUptime
        let precise = event.hasPreciseScrollingDeltas

        if event.phase == .ended || event.momentumPhase == .ended {
            accumulatedX = 0
            accumulatedY = 0
            return nil
        }

        accumulatedX += event.scrollingDeltaX
        accumulatedY += event.scrollingDeltaY

        let threshold: CGFloat = precise ? 24 : 1
        var forward: Bool?
        if abs(accumulatedX) >= threshold {
            forward = accumulatedX > 0
        } else if abs(accumulatedY) >= threshold {
            forward = accumulatedY < 0
        }

        guard let forward else { return nil }
        accumulatedX = 0
        accumulatedY = 0

        guard now - lastStep > (precise ? 0.16 : 0.08) else { return nil }
        lastStep = now
        model.stepMonth(forward ? 1 : -1)
        return nil
    }
}
