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
        // Critical for receiving keyboard input in a status bar app
        NSApp.setActivationPolicy(.accessory)
        
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
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 1. Skip if we are ignoring clicks manually
                if self.ignoreNextOutsideClick {
                    print("⏭️ Ignoring outside click (was from menu)")
                    self.ignoreNextOutsideClick = false
                    return
                }
                
                // 2. Geometry Check: Is the click actually inside our window?
                // Sometimes clicks on non-key windows are reported as global
                if let window = self.window, window.isVisible {
                    let clickLocation = NSEvent.mouseLocation // Global screen coordinates
                    if window.frame.contains(clickLocation) {
                        print("✋ Click inside window frame detected (Global Monitor) - Ignoring collapse")
                        return
                    }
                }
                
                // 3. Collapse if genuinely outside
                if IslandState.shared.isExpanded {
                    print("👆 Outside click detected - collapsing")
                    IslandState.shared.collapse()
                } else if IslandState.shared.mode != .idle {
                    print("👆 Outside click detected while collapsed - hiding (going idle)")
                    IslandState.shared.setMode(.idle)
                }
            }
        }
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Minimalist dot for the menu bar
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "PULSE")
            button.image?.isTemplate = true // Ensures it follows system light/dark mode
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
        window?.ignoresMouseEvents = false // Restore interactivity
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
        window?.ignoresMouseEvents = true // Let clicks pass through
        print("   - window.alphaValue set to 0, ignoresMouseEvents = true")
    }
    
    func updateWindowVisibility() {
        if IslandState.shared.isDisabled {
            window?.alphaValue = 0.0
            window?.ignoresMouseEvents = true
        } else {
            window?.alphaValue = 1.0
            window?.ignoresMouseEvents = false
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
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 1000),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .statusBar
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
            
        // Force focus when entering edit mode (Notes)
        IslandState.shared.$editingNoteIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] index in
                if index != nil {
                    print("📝 Note Editor Entered. Attempting to steal focus...")
                    self?.handleStateChange()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("   - Activating App (NSRunningApplication force)...")
                        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
                        
                        if let window = self?.window {
                            // Bump level to ensure it captures clicks
                            window.level = .floating
                            window.makeKeyAndOrderFront(nil)
                            window.makeKey()
                            print("   - Window Level set to .floating")
                            print("   - Is Key Window Now? \(window.isKeyWindow)")
                        }
                    }
                } else {
                    // Reset level when leaving edit mode
                    self?.window?.level = .statusBar
                }
            }
            .store(in: &cancellables)
            
        // Log frame for debugging
        if let window = self.window {
            print("🪟 Current Window Frame: \(window.frame)")
        }
            
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recenterWindow()
        }
    }

    private func handleStateChange() {
        DispatchQueue.main.async {
            self.recenterWindow()
            if IslandState.shared.isExpanded {
                self.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }


    func recenterWindow() {
        guard let window = window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        
        let state = IslandState.shared
        let notchInfo = NotchDetector.notchInfo(for: targetScreen)
        
        // Update state with notch info for adaptive UI
        if notchInfo.hasNotch, let rect = notchInfo.notchRect {
            state.hasNotch = true
            state.notchWidth = rect.width
            state.notchHeight = rect.height
        } else {
            state.hasNotch = false
        }
        
        let width = state.widthForMode(state.mode, isExpanded: state.isExpanded)
        let height = state.heightForMode(state.mode, isExpanded: state.isExpanded)
        
        let x: CGFloat
        let y: CGFloat
        
        if let notchRect = notchInfo.notchRect {
            // Center horizontally relative to the notch
            x = notchRect.midX - (width / 2)
            
            if state.isExpanded {
                // Expanded: Stick to absolute top
                let screenFrame = targetScreen.frame
                y = screenFrame.maxY - height
            } else {
                // Compact: Stick to absolute top
                let screenFrame = targetScreen.frame
                y = screenFrame.maxY - height
            }
            print("🏝️ Notch detected at \(notchRect), positioning island at (\(x), \(y))")
        } else {
            // Fallback for screens without notch
            let screenFrame = targetScreen.frame
            let visibleFrame = targetScreen.visibleFrame
            
            x = screenFrame.origin.x + (screenFrame.width - width) / 2
            
            if state.hasNotch {
                if state.isExpanded {
                    y = visibleFrame.maxY - height
                } else {
                    y = screenFrame.maxY - height
                }
            } else {
                // Floating island when no notch
                y = screenFrame.maxY - height - 10
            }
            print("🏝️ No notch detected, positioning island at top center (\(x), \(y))")
        }
        
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: false)
    }
}
