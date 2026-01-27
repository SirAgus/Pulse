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
    @Published var isDisabled: Bool = false {
        didSet {
            if isDisabled {
                setMode(.idle)
                isExpanded = false
            } else {
                setMode(.compact)
            }
        }
    }
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
    @Published var trackPosition: Double = 0
    @Published var trackDuration: Double = 1
    
    // Headphones State
    @Published var headphoneName: String? = nil
    @Published var headphoneBattery: Int? = nil
    
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
        
        // Timer to increment song progress
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying && self.trackPosition < self.trackDuration {
                self.trackPosition += 1
            }
        }
        
        // Timer to refresh headphone status
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshHeadphoneStatus()
        }
        
        refreshHeadphoneStatus()
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
        let apps = NSWorkspace.shared.runningApplications
        let isSpotifyRunning = apps.contains { $0.bundleIdentifier == "com.spotify.client" }
        let isMusicRunning = apps.contains { $0.bundleIdentifier == "com.apple.Music" }
        
        // Target specifically the app that is currently active or running
        // Using 'tell application id' is safer and doesn't launch the app if it's not open
        if currentPlayer == "Spotify" && isSpotifyRunning {
            executeAppleScript("tell application \"Spotify\" to \(command)")
        } else if currentPlayer == "Music" && isMusicRunning {
            executeAppleScript("tell application \"Music\" to \(command)")
        } else {
            // Priority fallback
            if isSpotifyRunning {
                executeAppleScript("tell application \"Spotify\" to \(command)")
            } else if isMusicRunning {
                executeAppleScript("tell application \"Music\" to \(command)")
            }
        }
        
        // Optimistic UI update
        if command == "playpause" {
            withAnimation { self.isPlaying.toggle() }
        }
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
        refreshHeadphoneStatus()
        
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
    
    func executeAppleScript(_ scriptSource: String) -> String? {
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
    
    func refreshHeadphoneStatus() {
        // Use ioreg to find Bluetooth devices with battery info
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-r", "-k", "BatteryPercent"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            // Very simplified regex-like check
            if output.contains("BatteryPercent") {
                // Try to find a name near it
                let lines = output.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if line.contains("BatteryPercent") {
                        if let percent = Int(line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                            DispatchQueue.main.async {
                                self.headphoneBattery = percent
                                // We'll just call them 'Audífonos' if we can't find a clean name
                                self.headphoneName = "AirPods" 
                            }
                            return
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.headphoneName = nil
            self.headphoneBattery = nil
        }
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
