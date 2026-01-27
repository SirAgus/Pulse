import SwiftUI
import AppKit
import Combine
import CoreWLAN
import IOBluetooth
import CoreLocation
import EventKit

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
    case productivity // For Pomodoro/Meeting
}

enum BackgroundStyle: String, CaseIterable {
    case solid = "Sólido"
    case liquidGlass = "Liquid Glass"
    case liquidGlassDark = "Liquid Glass Dark"
}

struct BluetoothDevice: Identifiable, Equatable {
    let id: String // MAC Address
    let name: String
    let isConnected: Bool
    let batteryPercentage: Int?
}

class IslandState: ObservableObject {
    static let shared = IslandState()
    
    @Published var mode: IslandMode = .compact
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
    
    // Headphones & Bluetooth State
    @Published var headphoneName: String? = nil
    @Published var headphoneBattery: Int? = nil
    @Published var bluetoothDevices: [BluetoothDevice] = []
    
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
    let categories = ["Favoritos", "Recientes", "Dispositivos", "Utilidades", "Configuración"]
    
    
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
    @Published var backgroundStyle: BackgroundStyle = .solid
    
    // Meeting Mode
    @Published var isMicMuted: Bool = false
    @Published var isDNDActive: Bool = false
    
    // Clipboard
    @Published var clipboardHistory: [String] = []
    private var lastChangeCount: Int = 0
    
    // Weather
    @Published var currentTemp: Double?
    @Published var precipitationProb: Int?
    @Published var weatherCity: String = "São Paulo" // Placeholder or detected
    
    // Calendar
    struct CalendarEvent: Identifiable {
        let id: String
        let title: String
        let startDate: Date
        let location: String?
        let url: URL?
    }
    @Published var nextEvent: CalendarEvent?
    private let eventStore = EKEventStore()
    
    // Pomodoro
    enum PomodoroMode { case work, shortBreak, longBreak }
    @Published var pomodoroMode: PomodoroMode = .work
    @Published var pomodoroRemaining: TimeInterval = 25 * 60
    @Published var isPomodoroRunning: Bool = false
    @Published var pomodoroCycles: Int = 0
    
    private var collapseTimer: Timer?

    init() {
        self.mode = .compact
        self.isExpanded = false
        
        startMockUpdates()
        refreshVolume()
        
        // Fast timer for clipboard and music progress
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.refreshClipboard()
            self.updatePomodoro()
            
            // Song progress
            if self.isPlaying && self.trackPosition < self.trackDuration {
                self.trackPosition += 1
            }
            
            // Countdown Timer
            if self.isTimerRunning && self.timerRemaining > 0 {
                self.timerRemaining -= 1
                if self.timerRemaining == 0 {
                    self.showNotification("¡Temporizador Finalizado!")
                    self.isTimerRunning = false
                }
            }
        }
        
        // Slower timer for Weather and Calendar (every 10 mins)
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refreshWeather()
            self?.refreshCalendar()
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
            self?.refreshBluetoothDevices()
            self?.refreshWiFiStatus()
        }
        
        refreshHeadphoneStatus()
        refreshBluetoothDevices()
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
            // Using a loop with a custom delimiter (|||) to handle note names with commas
            let script = """
            tell application "Notes"
                set out to ""
                repeat with n in every note
                    set out to out & (id of n) & "|||" & (name of n) & linefeed
                end repeat
                return out
            end tell
            """
            
            guard let result = self.executeAppleScript(script) else {
                DispatchQueue.main.async { self.isSyncingNotes = false }
                return
            }
            
            let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var collected: [NoteItem] = []
            
            for line in lines {
                let parts = line.components(separatedBy: "|||")
                if parts.count >= 2 {
                    collected.append(NoteItem(id: parts[0], content: parts[1]))
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
    
    func openNotesApp() {
        let script = "tell application \"Notes\" to activate"
        executeAppleScript(script)
    }

    func showNotification(_ text: String) {
        // Mock notification for now
        print(text)
    }
    
    func toggleExpand() {
        if isExpanded {
            collapse()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                isExpanded = true
            }
            cancelCollapseTimer()
        }
    }
    
    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            isExpanded = false
        }
        if !isHovering {
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
    }
    
    func refreshVolume() {
        let script = "set volume output volume \(Int(volume * 100))"
        executeAppleScript(script)
    }

    // Bluetooth Control (Native)
    func refreshBluetoothDevices() {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { 
            DispatchQueue.main.async { self.bluetoothDevices = [] }
            return 
        }
        
        var discovered: [BluetoothDevice] = []
        for device in pairedDevices {
            if device.isConnected() {
                discovered.append(BluetoothDevice(
                    id: device.addressString,
                    name: device.nameOrAddress,
                    isConnected: true,
                    batteryPercentage: nil
                ))
            }
        }
        
        DispatchQueue.main.async {
            self.bluetoothDevices = discovered
            
            // Sync headphoneName if a connected device looks like one
            // We search for audio-like devices
            if let firstAudio = discovered.first(where: { 
                $0.name.lowercased().contains("buds") || 
                $0.name.lowercased().contains("airpods") || 
                $0.name.lowercased().contains("headphones") ||
                $0.name.lowercased().contains("audio") 
            }) {
                self.headphoneName = firstAudio.name
            } else if let first = discovered.first {
                self.headphoneName = first.name
            }
        }
    }
    
    func disconnectBluetoothDevice(address: String) {
        if let device = IOBluetoothDevice(addressString: address) {
            device.closeConnection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshBluetoothDevices()
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
        if named == "Settings" {
            selectedApp = "Settings"
            setMode(.compact)
            isExpanded = true
            return
        }
        if ["Meeting", "Clipboard", "Weather", "Calendar", "Pomodoro", "Settings"].contains(named) {
            selectedApp = named
            // Correct the active category to match the app being opened
            if named == "Settings" { activeCategory = "Configuración" }
            else if ["Meeting", "Clipboard", "Pomodoro", "Calendar"].contains(named) { activeCategory = "Favoritos" }
            else if named == "Weather" { activeCategory = "Utilidades" }
            
            setMode(.compact)
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
    
    // MARK: - Meeting Mode
    func toggleMic() {
        let script = """
        set v to input volume of (get volume settings)
        if v is 0 then
            set volume input volume 100
            return "unmuted"
        else
            set volume input volume 0
            return "muted"
        end if
        """
        if let res = executeAppleScript(script) {
            isMicMuted = (res.trimmingCharacters(in: .whitespacesAndNewlines) == "muted")
        }
    }
    
    func refreshMicStatus() {
        if let volStr = executeAppleScript("input volume of (get volume settings)"), let vol = Int(volStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            isMicMuted = (vol == 0)
        }
    }
    
    func toggleDND() {
        // Runs the "DND Toggle" shortcut if it exists
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/shortcuts"
            task.arguments = ["run", "DND Toggle"]
            try? task.run()
            DispatchQueue.main.async {
                self.isDNDActive.toggle()
            }
        }
    }
    
    // MARK: - Clipboard
    func refreshClipboard() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            if let str = pasteboard.string(forType: .string) {
                if !clipboardHistory.contains(str) {
                    clipboardHistory.insert(str, at: 0)
                    if clipboardHistory.count > 10 { clipboardHistory.removeLast() }
                }
            }
        }
    }
    
    func pasteFromHistory(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // MARK: - Weather
    func refreshWeather() {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=-23.55&longitude=-46.63&current=temperature_2m&hourly=precipitation_probability&timezone=auto")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any],
               let temp = current["temperature_2m"] as? Double {
                DispatchQueue.main.async {
                    self.currentTemp = temp
                    if let hourly = json["hourly"] as? [String: Any],
                       let probs = hourly["precipitation_probability"] as? [Int] {
                        self.precipitationProb = probs.first
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Calendar
    func refreshCalendar() {
        eventStore.requestAccess(to: .event) { granted, error in
            if granted {
                let calendars = self.eventStore.calendars(for: .event)
                let start = Date()
                let end = Date().addingTimeInterval(86400 * 2) 
                let predicate = self.eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
                let events = self.eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
                
                if let first = events.first {
                    DispatchQueue.main.async {
                        self.nextEvent = CalendarEvent(
                            id: first.eventIdentifier,
                            title: first.title,
                            startDate: first.startDate,
                            location: first.location,
                            url: first.url
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Pomodoro
    func startPomodoro() {
        isPomodoroRunning = true
        setMode(.productivity)
    }
    
    func pausePomodoro() {
        isPomodoroRunning = false
    }
    
    func resetPomodoro() {
        isPomodoroRunning = false
        pomodoroRemaining = (pomodoroMode == .work ? 25 : 5) * 60
    }
    
    private func updatePomodoro() {
        guard isPomodoroRunning else { return }
        if pomodoroRemaining > 0 {
            pomodoroRemaining -= 1
        } else {
            if pomodoroMode == .work {
                pomodoroCycles += 1
                pomodoroMode = .shortBreak
                pomodoroRemaining = 5 * 60
                showNotification("¡Enfoque terminado! Descanso.")
            } else {
                pomodoroMode = .work
                pomodoroRemaining = 25 * 60
                showNotification("¡Descanso terminado! A trabajar.")
            }
            isPomodoroRunning = false
        }
    }
    
    func formatPomodoroTime() -> String {
        let mins = Int(pomodoroRemaining) / 60
        let secs = Int(pomodoroRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Dimension Helpers
    
    func widthForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 450
            case .music: return 400
            case .timer: return 350
            case .notes: return 380
            case .productivity: return 450
            default: return 320
            }
        } else {
            switch mode {
            case .idle: return 20
            case .compact: return 120
            case .music: return 200
            case .battery: return 100
            case .volume: return 100
            case .timer: return 140
            case .notes: return 120
            case .productivity: return 180
            }
        }
    }
    
    func heightForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 600
            case .music: return 220
            case .battery: return 70
            case .volume: return 60
            case .timer: return 180
            case .notes: return 450
            case .productivity: return 600
            default: return 160
            }
        } else {
            switch mode {
            case .idle: return 1 
            case .timer, .notes, .productivity: return 35
            default: return 35
            }
        }
    }
}
