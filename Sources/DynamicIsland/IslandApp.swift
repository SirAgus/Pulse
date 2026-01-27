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
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupIslandWindow()
        MusicObserver.shared.start()
        BatteryObserver.shared.start()
        VolumeObserver.shared.start()
        setupClickOutsideMonitor()
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupClickOutsideMonitor() {
        // Global monitor catches clicks on other apps/desktop
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                if IslandState.shared.isExpanded {
                    IslandState.shared.collapse()
                }
            }
        }
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Island Control")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Mostrar/Ocultar Isla", action: #selector(toggleIsland), keyEquivalent: "i"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Configuración", action: nil, keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func statusItemClicked() {
        // This is called when the button is clicked but no menu is set
        // Since we set a menu, this won't be called unless we handle it differently
    }
    
    @objc func toggleIsland() {
        IslandState.shared.isDisabled.toggle()
        updateWindowVisibility()
    }
    
    func updateWindowVisibility() {
        if IslandState.shared.isDisabled {
            window?.orderOut(nil)
        } else {
            window?.orderFront(nil)
            recenterWindow()
        }
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
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.recenterWindow()
                self.updateWindowVisibility()
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
        
        // Final pixel-perfect centering math
        // We use the EXACT size of the island for the window to avoid blocking clicks
        let actualWidth = width
        let actualHeight = height
        
        let x = screenFrame.origin.x + (screenFrame.width - actualWidth) / 2
        
        // Position below notch (usually 35-40px from top)
        let topMargin: CGFloat = 35
        let y = screenFrame.maxY - actualHeight - topMargin
        
        window.setFrame(NSRect(x: x, y: y, width: actualWidth, height: actualHeight), display: true, animate: false)
    }
}
