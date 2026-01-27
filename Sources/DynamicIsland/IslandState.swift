import SwiftUI
import Combine

enum IslandMode {
    case idle
    case compact
    case music
    case battery
    case volume
}

class IslandState: ObservableObject {
    static let shared = IslandState()
    
    @Published var mode: IslandMode = .idle
    @Published var isExpanded: Bool = false
    @Published var isHovering: Bool = false {
        didSet {
            if isHovering {
                cancelCollapseTimer()
                // If we are idle, automatically show compact mode on hover
                if mode == .idle {
                    setMode(.compact, autoCollapse: false)
                }
            } else {
                startCollapseTimer()
            }
        }
    }
    
    // Music State
    @Published var songTitle: String = ""
    @Published var artistName: String = ""
    @Published var isPlaying: Bool = false
    
    // Battery State
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    
    // Volume State
    @Published var volume: Double = 0.5
    
    // Mock Notifications/Messages
    @Published var selectedApp: String? = nil
    @Published var lastWhatsAppMessages: [String] = ["Juan: ¿Vienes a la reunión?", "Mamá: Te dejé comida en el horno"]
    @Published var lastSlackMessages: [String] = ["Lucas: Tenemos deploy en 5 min", "Sara: El diseño está aprobado ✅"]
    @Published var lastSpotifyMessages: [String] = ["Playlist: 'Descubrimiento semanal'", "Podcast: 'The Joe Rogan Experience'"]
    
    @Published var wspBadge: String = ""
    @Published var slackBadge: String = ""
    
    private var collapseTimer: Timer?

    init() {
        startMockUpdates()
    }
    
    func toggleExpand() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            isExpanded.toggle()
        }
        
        if isExpanded {
            cancelCollapseTimer()
        } else if !isHovering {
            startCollapseTimer()
        }
    }
    
    func setMode(_ newMode: IslandMode, autoCollapse: Bool = true) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            mode = newMode
            // For modes like volume/battery, we might want them expanded initially
            if newMode == .battery {
                isExpanded = true
            }
        }
        
        if autoCollapse && newMode != .idle && !isHovering {
            startCollapseTimer()
        }
    }

    func startCollapseTimer() {
        cancelCollapseTimer()
        // 10 seconds as requested
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.isHovering && !self.isPlaying {
                self.setMode(.idle)
                withAnimation { self.isExpanded = false }
            }
        }
    }

    func cancelCollapseTimer() {
        collapseTimer?.invalidate()
        collapseTimer = nil
    }
    
    func openApp(named: String) {
        // Toggle selection for messages instead of immediate launch
        if selectedApp == named {
            // If already selected, then launch it
            launchApp(named: named)
            withAnimation { 
                isExpanded = false 
                selectedApp = nil
            }
            setMode(.idle)
        } else {
            withAnimation(.spring()) {
                selectedApp = named
                refreshRealStatus()
            }
        }
    }
    
    func refreshRealStatus() {
        // WhatsApp Badge check via AppleScript
        let wspScript = "tell application \"Dock\" to get badge label of UI element \"WhatsApp\" of list 1"
        if let badge = executeAppleScript(wspScript), !badge.isEmpty {
            wspBadge = badge
            lastWhatsAppMessages = ["Tienes \(badge) mensajes nuevos en WhatsApp"]
        }
        
        // Slack Badge check
        let slackScript = "tell application \"Dock\" to get badge label of UI element \"Slack\" of list 1"
        if let badge = executeAppleScript(slackScript), !badge.isEmpty {
            slackBadge = badge
            lastSlackMessages = ["Tienes \(badge) notificaciones en Slack"]
        }
    }
    
    private func executeAppleScript(_ scriptSource: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
    
    private func launchApp(named: String) {
        let appName = named == "Wsp" ? "WhatsApp" : named
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName == appName }) {
            app.activate(options: .activateIgnoringOtherApps)
        } else {
            let path = "/Applications/\(appName).app"
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } else {
                if let url = URL(string: "macappstore://showProducts?term=\(appName)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func startMockUpdates() {
        // No mocks for now
    }
    
    // MARK: - Dimension Helpers
    
    func widthForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 450 // Wider for messages
            case .music: return 360
            case .battery: return 220
            case .volume: return 200
            default: return 300
            }
        } else {
            switch mode {
            case .idle: return 20
            case .compact: return 100
            case .music: return 160
            case .battery: return 100
            case .volume: return 100
            }
        }
    }
    
    func heightForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 220 // Taller for messages
            case .music: return 190
            case .battery: return 70
            case .volume: return 60
            default: return 160
            }
        } else {
            switch mode {
            case .idle: return 5
            default: return 30
            }
        }
    }
}
