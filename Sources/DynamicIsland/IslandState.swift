import SwiftUI
import AppKit
import Combine
import CoreWLAN

struct NoteItem: Identifiable, Equatable {
    let id: String
    var content: String
}

enum IslandMode {
    case idle
    case compact
    case music
    case battery
    case volume
    case timer
    case notes
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
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying && mode != .music {
                setMode(.music)
            } else if !isPlaying && mode == .music {
                setMode(.compact)
            }
        }
    }
    @Published var currentPlayer: String = "Spotify"
    @Published var trackPosition: Double = 0
    @Published var trackDuration: Double = 1
    @Published var trackArtwork: NSImage? = nil
    @Published var bars: [CGFloat] = Array(repeating: 4, count: 12)
    
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
    // Categories and App State
    @Published var activeCategory: String = "Favoritos" {
        didSet {
            selectedApp = nil
        }
    }
    let categories = ["Favoritos", "Recientes", "Dispositivos", "Utilidades"]
    
    
    // Timer State
    @Published var timerRemaining: TimeInterval = 0
    @Published var isTimerRunning: Bool = false
    @Published var timerTotal: TimeInterval = 0
    @Published var customTimerMinutes: Double = 5
    
    // Notes
    @Published var notes: [NoteItem] = []
    @Published var editingNoteIndex: Int? = nil
    @Published var isSyncingNotes: Bool = false
    
    // Wi-Fi
    @Published var wifiSSID: String = "Wi-Fi"
    
    // Settings
    @Published var islandColor: Color = .black
    @Published var showClock: Bool = true
    @Published var accentColor: Color = .orange
    
    private var collapseTimer: Timer?

    init() {
        startMockUpdates()
        refreshVolume()
        
        // Timer to increment song progress and handles Timer widget
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Song progress
            if self.isPlaying && self.trackPosition < self.trackDuration {
                self.trackPosition += 1
            }
            
            // Countdown Timer
            if self.isTimerRunning && self.timerRemaining > 0 {
                self.timerRemaining -= 1
                if self.timerRemaining <= 0 {
                    self.isTimerRunning = false
                    self.showNotification("¡Tiempo terminado!")
                }
            }
        }
        
        // Timer for Visualizer Bars
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying {
                self.bars = self.bars.map { _ in CGFloat.random(in: 6...28) }
            }
        }
        
        // Timer to refresh status (Headphones, WiFi, etc)
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshHeadphoneStatus()
            self?.refreshWiFiStatus()
        }
        
        refreshHeadphoneStatus()
        refreshWiFiStatus()
        refreshNotes()
    }
    
    func refreshWiFiStatus() {
        // Try native first
        if let interface = CWWiFiClient.shared().interface(), let ssid = interface.ssid() {
            DispatchQueue.main.async { self.wifiSSID = ssid }
            return
        }
        
        // Fallback to shell command
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getairportnetwork", "en0"] // en0 is standard for WiFi
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), output.contains("Current Wi-Fi Network:") {
            let ssid = output.replacingOccurrences(of: "Current Wi-Fi Network: ", with: "").trimmingCharacters(in: .newlines)
            DispatchQueue.main.async { self.wifiSSID = ssid }
        } else {
            DispatchQueue.main.async { self.wifiSSID = "Conectado" }
        }
    }
    
    func startTimer(minutes: Double) {
        timerTotal = (minutes > 0 ? minutes : customTimerMinutes) * 60
        timerRemaining = timerTotal
        isTimerRunning = true
        setMode(.compact)
    }
    
    func stopTimer() {
        isTimerRunning = false
    }
    
    // Notes Management (Native Sync)
    func refreshNotes() {
        isSyncingNotes = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Get IDs and names separately as AppleScript struggles with complex objects
            let idsScript = "tell application \"Notes\" to get id of every note"
            let namesScript = "tell application \"Notes\" to get name of every note"
            
            let idsRaw = self.executeAppleScript(idsScript) ?? ""
            let namesRaw = self.executeAppleScript(namesScript) ?? ""
            
            let ids = idsRaw.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let names = namesRaw.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            var collected: [NoteItem] = []
            for i in 0..<min(ids.count, names.count) {
                if !ids[i].isEmpty {
                    collected.append(NoteItem(id: ids[i], content: names[i]))
                }
            }
            
            DispatchQueue.main.async {
                self.notes = collected
                self.isSyncingNotes = false
            }
        }
    }
    
    func addNote() {
        let script = "tell application \"Notes\" to make new note with properties {body:\"Nueva Nota de Dynamic Island\"}"
        executeAppleScript(script)
        refreshNotes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.editingNoteIndex = 0
        }
    }
    
    func deleteNote(at index: Int) {
        guard notes.indices.contains(index) else { return }
        let noteID = notes[index].id
        let script = "tell application \"Notes\" to delete note id \"\(noteID)\""
        executeAppleScript(script)
        refreshNotes()
    }

    func saveNote(at index: Int, newContent: String) {
        guard notes.indices.contains(index) else { return }
        let noteID = notes[index].id
        // Replace quotes to avoid script errors
        let safeContent = newContent.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Notes\" to set body of note id \"\(noteID)\" to \"<div>\(safeContent)</div>\""
        executeAppleScript(script)
        refreshNotes()
    }

    func showNotification(_ text: String) {
        // Mock notification for now
        print(text)
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
        
        let targetApp = currentPlayer.isEmpty ? (isSpotifyRunning ? "Spotify" : (isMusicRunning ? "Music" : nil)) : currentPlayer
        
        guard let app = targetApp, app != "Unknown" else { return }
        
        // Optimistic UI update for play/pause
        if command == "playpause" {
            withAnimation { self.isPlaying.toggle() }
        }
        
        // Robust execution
        let script = "tell application \"\(app)\" to \(command)"
        executeAppleScript(script)
        
        // Refresh duration after command
        MusicObserver.shared.checkCurrentStatus()
    }
    
    func playPause() { musicControl("playpause") }
    func nextTrack() { musicControl("next track") }
    func previousTrack() { musicControl("previous track") }
    
    func openAirPlay() {
        // Universal way to open the sound/airplay picker via Control Center
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                set menuBarItems to menu bar items of menu bar 1
                repeat with mi in menuBarItems
                    set desc to description of mi
                    if desc contains "Sound" or desc contains "Sonido" or desc contains "Volume" or desc contains "Volumen" or desc contains "Música" or desc contains "AirPlay" then
                        click mi
                        return
                    end if
                end repeat
                -- Fallback keyboard shortcut if UI search fails
                key code 28 using {control down, command down}
            end tell
        end tell
        """
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
        if named == "Timer" {
            setMode(.timer)
            isExpanded = true
            return
        }
        if named == "Notes" {
            setMode(.notes)
            isExpanded = true
            return
        }
        
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
        // AGGRESSIVE IOREG SCAN
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-n", "AppleDeviceManagementHIDEventService", "-r", "-l"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let devices = output.components(separatedBy: "DeviceAddress")
                for device in devices where device.contains("BatteryPercent") {
                    let lines = device.components(separatedBy: .newlines)
                    var battery: Int?
                    var name: String?
                    
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.contains("\"BatteryPercent\" =") || trimmed.contains("\"BatteryPercentMain\" =") {
                            battery = Int(trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                        }
                        if trimmed.contains("\"Product\" =") {
                            name = trimmed.components(separatedBy: "\"").dropFirst(3).first
                        }
                    }
                    
                    if let batt = battery {
                        DispatchQueue.main.async {
                            self.headphoneName = name ?? "Audífonos"
                            self.headphoneBattery = batt
                        }
                        return
                    }
                }
            }
        } catch {}

        // Fallback to system_profiler if ioreg is empty
        let profiler = Process()
        profiler.launchPath = "/usr/sbin/system_profiler"
        profiler.arguments = ["SPBluetoothDataType", "-json"]
        let pPipe = Pipe()
        profiler.standardOutput = pPipe
        
        profiler.terminationHandler = { [weak self] _ in
            let data = pPipe.fileHandleForReading.readDataToEndOfFile()
            guard let self = self,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let controllers = json["SPBluetoothDataType"] as? [[String: Any]],
                  let devices = controllers.first?["device_title"] as? [[String: Any]] else {
                return
            }
            
            for wrapper in devices {
                guard let deviceName = wrapper.keys.first,
                      let details = wrapper[deviceName] as? [String: Any],
                      details["device_connected"] as? String == "ATT_CONNECTED" || details["device_connected"] as? String == "true" else {
                    continue
                }
                
                if let batteryStr = (details["device_batteryLevelMain"] as? String) ?? (details["device_batteryLevelCase"] as? String),
                   let level = Int(batteryStr.replacingOccurrences(of: "%", with: "")) {
                    DispatchQueue.main.async {
                        self.headphoneName = deviceName
                        self.headphoneBattery = level
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                self.headphoneName = nil
                self.headphoneBattery = nil
            }
        }
        
        try? profiler.run()
    }
    
    private func launchApp(named: String) {
        let appName: String = {
            switch named {
            case "Wsp": return "WhatsApp"
            case "Chrome": return "Google Chrome"
            case "Weather": return "Clima"
            case "Calendar": return "Calendario"
            default: return named
            }
        }()
        
        let bundleID: String? = {
            switch named {
            case "Wsp": return "net.whatsapp.WhatsApp"
            case "Spotify": return "com.spotify.client"
            case "Slack": return "com.tinyspeck.slackmacgap"
            case "Finder": return "com.apple.finder"
            case "Chrome": return "com.google.Chrome"
            case "Calendar": return "com.apple.iCal"
            case "Weather": return "com.apple.weather"
            case "Notes": return "com.apple.Notes"
            default: return nil
            }
        }()
        
        if let bid = bundleID, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            NSWorkspace.shared.open(appURL)
            return
        }
        
        // Fallback to searching /Applications and /System/Applications
        let searchPaths = ["/Applications", "/System/Applications"]
        for path in searchPaths {
            let appPath = "\(path)/\(appName).app"
            if FileManager.default.fileExists(atPath: appPath) {
                NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
                return
            }
            
            // Try English name if searching for Clima/Calendario
            let englishName = named // e.g. "Weather", "Calendar"
            let engPath = "\(path)/\(englishName).app"
            if FileManager.default.fileExists(atPath: engPath) {
                NSWorkspace.shared.open(URL(fileURLWithPath: engPath))
                return
            }
        }
        
        // Final fallback: try to run it
        NSWorkspace.shared.launchApplication(appName)
    }
    
    private func startMockUpdates() {
        // No mocks for now
    }
    
    // MARK: - Dimension Helpers
    
    func widthForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 420
            case .music: return 380
            case .timer: return 320
            case .notes: return 350
            default: return 300
            }
        } else {
            switch mode {
            case .idle: return 20
            case .compact: return 120
            case .music: return 180
            case .battery: return 100
            case .volume: return 100
            case .timer: return 140
            case .notes: return 120
            }
        }
    }
    
    func heightForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 480 
            case .music: return 220
            case .battery: return 70
            case .volume: return 60
            case .timer: return 180
            case .notes: return 180
            default: return 160
            }
        } else {
            switch mode {
            case .idle: return 1 
            case .timer, .notes: return 35
            default: return 35
            }
        }
    }
}
