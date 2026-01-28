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

class IslandWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: IslandWindow?
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var ignoreNextOutsideClick = false  // Flag to ignore menu clicks

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
                guard let self = self else { return }
                
                // Skip if we're ignoring clicks (e.g., right after showing from menu)
                if self.ignoreNextOutsideClick {
                    print("⏭️ Ignoring outside click (was from menu)")
                    self.ignoreNextOutsideClick = false
                    return
                }
                
                if IslandState.shared.isExpanded {
                    print("👆 Outside click detected - collapsing")
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
        menu.addItem(NSMenuItem(title: "Mostrar Isla", action: #selector(showIsland), keyEquivalent: "i"))
        menu.addItem(NSMenuItem(title: "Ocultar Isla", action: #selector(hideIsland), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Configuración", action: nil, keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func statusItemClicked() {
        // This is called when the button is clicked but no menu is set
    }
    
    @objc func showIsland() {
        // Ignore the menu click that triggered this
        ignoreNextOutsideClick = true
        
        let state = IslandState.shared
        
        print("🏝️ showIsland called")
        print("   - isDisabled: \(state.isDisabled)")
        print("   - isExpanded: \(state.isExpanded)")
        print("   - mode: \(state.mode)")
        print("   - window: \(String(describing: window))")
        print("   - window.isVisible: \(window?.isVisible ?? false)")
        
        // Enable if disabled
        if state.isDisabled {
            print("   → Enabling island (was disabled)")
            state.isDisabled = false
        }
        
        // Set to compact mode and expand
        print("   → Setting mode to compact and expanding")
        state.setMode(.compact, autoCollapse: false)
        state.expand()
        
        // Ensure window is visible - use alphaValue instead of orderOut/orderFront
        print("   → Making window visible")
        window?.alphaValue = 1.0
        window?.orderFrontRegardless()
        recenterWindow()
        
        print("   - After: window.isVisible: \(window?.isVisible ?? false)")
        print("   - After: window.alphaValue: \(window?.alphaValue ?? 0)")
        print("   - After: window.frame: \(window?.frame ?? .zero)")
    }
    
    @objc func hideIsland() {
        print("🙈 hideIsland called")
        let state = IslandState.shared
        state.isDisabled = true
        state.collapse()
        // Use alphaValue instead of orderOut to hide - easier to recover
        window?.alphaValue = 0.0
        print("   - window.alphaValue set to 0")
    }
    
    func updateWindowVisibility() {
        if IslandState.shared.isDisabled {
            window?.alphaValue = 0.0
        } else {
            window?.alphaValue = 1.0
            window?.orderFrontRegardless()
            recenterWindow()
        }
    }

    func setupIslandWindow() {
        let islandView = IslandView()
            .environmentObject(IslandState.shared)

        let hostingView = NSHostingView(rootView: islandView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Use simple borderless NSWindow
        let window = IslandWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false // Shadow is handled by the View
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        
        window.contentView = hostingView
        
        self.window = window
        recenterWindow()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Only listen for relevant changes (mode or expansion) to avoid stealing focus while typing
        IslandState.shared.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleStateChange() }
            .store(in: &cancellables)
            
        IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleStateChange() }
            .store(in: &cancellables)
            
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recenterWindow()
        }
    }

    private func handleStateChange() {
        DispatchQueue.main.async {
            self.recenterWindow()
            if IslandState.shared.isExpanded {
                self.window?.orderFrontRegardless()
            }
        }
    }


    func recenterWindow() {
        guard let window = window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        
        let screenFrame = targetScreen.frame
        let visibleFrame = targetScreen.visibleFrame
        let state = IslandState.shared
        
        let width = state.widthForMode(state.mode, isExpanded: state.isExpanded)
        let height = state.heightForMode(state.mode, isExpanded: state.isExpanded)
        
        // Center horizontally on screen
        let x = screenFrame.origin.x + (screenFrame.width - width) / 2
        
        // Calculate Y position
        let y: CGFloat
        if state.isExpanded {
            // When expanded, position below the notch/menu bar
            y = visibleFrame.maxY - height
        } else {
            // When compact, position IN the notch area (very top of screen)
            // screenFrame.maxY is the absolute top, subtract small offset to center in notch
            let notchOffset: CGFloat = 5 // Small margin from absolute top
            y = screenFrame.maxY - height - notchOffset
        }
        
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: false)
    }
}
