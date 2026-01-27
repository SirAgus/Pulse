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
    @Published var currentPlayer: String = "Spotify"
    
    // Battery State
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    
    // Volume State
    @Published var volume: Double = 0.5
    
    // Mock Notifications/Messages
    @Published var selectedApp: String? = nil
    @Published var lastWhatsAppMessages: [String] = []
    @Published var lastSlackMessages: [String] = []
    @Published var lastSpotifyMessages: [String] = []
    
    @Published var wspBadge: String = ""
    @Published var slackBadge: String = ""
    
    private var collapseTimer: Timer?

    init() {
        startMockUpdates()
        refreshVolume()
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
            if newMode == .battery {
                isExpanded = true
            }
        }
        
        if autoCollapse && newMode != .idle && !isHovering {
            startCollapseTimer()
        }
    }
    
    func musicControl(_ command: String) {
        let appleMusicScript = "tell application \"Music\" to \(command)"
        let spotifyScript = "tell application \"Spotify\" to \(command)"
        
        executeAppleScript(appleMusicScript)
        executeAppleScript(spotifyScript)
    }
    
    func playPause() { musicControl("playpause") }
    func nextTrack() { musicControl("next track") }
    func previousTrack() { musicControl("previous track") }
    
    func openAirPlay() {
        // Toggle the system AirPlay/Sound picker
        let script = "tell application \"System Events\" to key code 28 using {control down, command down}" 
        executeAppleScript(script)
    }
    
    func adjustVolume(by delta: Int) {
        let script = "set volume output volume ((output volume of (get volume settings)) + \(delta))"
        executeAppleScript(script)
        // Give macOS a tiny moment to update settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.refreshVolume()
        }
    }
    
    func refreshVolume() {
        let script = "output volume of (get volume settings)"
        if let volStr = executeAppleScript(script), let volInt = Int(volStr) {
            DispatchQueue.main.async {
                self.volume = Double(volInt) / 100.0
            }
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
        } else {
            wspBadge = ""
            lastWhatsAppMessages = []
        }
        
        // Slack Badge check
        let slackScript = "tell application \"Dock\" to get badge label of UI element \"Slack\" of list 1"
        if let badge = executeAppleScript(slackScript), !badge.isEmpty {
            slackBadge = badge
            lastSlackMessages = ["Tienes \(badge) notificaciones en Slack"]
        } else {
            slackBadge = ""
            lastSlackMessages = []
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
    
    func showDashboard() {
        setMode(.compact, autoCollapse: false)
    }
    
    func showMusic() {
        setMode(.music, autoCollapse: false)
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
            case .compact: return 220 
            case .music: return 180 // Snugger
            case .battery: return 70
            case .volume: return 60
            default: return 160
            }
        } else {
            switch mode {
            case .idle: return 1 // Minimal to not block tabs
            default: return 30
            }
        }
    }
}
