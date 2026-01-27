import SwiftUI
import AppKit
import Combine

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupIslandWindow()
        MusicObserver.shared.start()
        BatteryObserver.shared.start()
        VolumeObserver.shared.start()
    }

    func setupIslandWindow() {
        let islandView = IslandView()
            .environmentObject(IslandState.shared)

        let hostingView = NSHostingView(rootView: islandView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use a fixed large initial size to avoid clipping or offset issues
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isFloatingPanel = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.hasShadow = false 
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        
        window.contentView = hostingView
        
        self.window = window
        recenterWindow()
        window.orderFront(nil)
        
        // Listen for state changes to resize the window snugly
        IslandState.shared.objectWillChange.sink { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.recenterWindow()
            }
        }.store(in: &cancellables)
        
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recenterWindow()
        }
    }

    func recenterWindow() {
        guard let window = window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let state = IslandState.shared
        
        let width = state.widthForMode(state.mode, isExpanded: state.isExpanded)
        let height = state.heightForMode(state.mode, isExpanded: state.isExpanded)
        
        // Use a snug window size to avoid blocking clicks on other screen areas
        // 300 is the minimum width to capture hover comfortably around the notch
        let actualWidth = max(width, 300)
        let actualHeight = max(height, 60) + 30 // +30 buffer for notch offset
        
        let x = screenFrame.origin.x + (screenFrame.width - actualWidth) / 2
        
        // Fixed top anchor point (5px below screen top)
        let topOffset: CGFloat = 5
        let y = screenFrame.maxY - actualHeight - topOffset
        
        // No animation for window frame resize to prevent "jitter"
        // SwiftUI will animate the internal content
        window.setFrame(NSRect(x: x, y: y, width: actualWidth, height: actualHeight), display: true, animate: false)
    }
}
