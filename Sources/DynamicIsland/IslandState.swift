import SwiftUI
import AppKit
import Combine
import CoreWLAN
import IOBluetooth
import CoreLocation
import EventKit
import IOKit

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

enum BackgroundStyle: String, CaseIterable, Codable {
    case solid = "Sólido"
    case liquidGlass = "Liquid Glass"
    case liquidGlassDark = "Liquid Glass Dark"
}

enum AppLanguage: String, CaseIterable, Codable {
    case spanish = "Español"
    case english = "English"
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
                isExpanded = false
            } else {
                setMode(.compact)
            }
        }
    }
    private var lastCollapseTime: Date = .distantPast
    
    @Published var isHovering: Bool = false {
        didSet {
            if isHovering {
                cancelCollapseTimer()
                
                // Don't re-expand if we just collapsed (prevents loop when clicking outside)
                let timeSinceCollapse = Date().timeIntervalSince(lastCollapseTime)
                if timeSinceCollapse < 0.5 {
                    print("🛡️ Blocking hover expansion (too soon after collapse)")
                    return
                }

                if mode == .idle {
                    setMode(.compact, autoCollapse: false)
                }
                if !isExpanded {
                    expand()
                }
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
    
    // Notch dimensions
    @Published var notchWidth: CGFloat = 209 // Default MBP 14 size
    @Published var notchHeight: CGFloat = 38
    @Published var hasNotch: Bool = false
    
    // Battery State
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    
    // Volume State
    @Published var volume: Double = 0.5
    @Published var appVolume: Double = 1.0
    
    // Mock Notifications/Messages
    @Published var selectedApp: String? = nil
    @Published var lastWhatsAppMessages: [String] = []
    @Published var lastSlackMessages: [String] = []
    @Published var lastSpotifyMessages: [String] = []
    
    @Published var wspBadge: String = ""
    @Published var slackBadge: String = ""
    // Categories and App State
    @Published var activeCategory: String = "Apps" {
        didSet {
            selectedApp = nil
        }
    }
    let categories = ["Apps", "Favoritos", "Recientes", "Dispositivos", "Utilidades", "Configuración"]
    
    
    // Timer State
    @Published var timerRemaining: TimeInterval = 0
    @Published var isTimerRunning: Bool = false
    @Published var timerTotal: TimeInterval = 0
    @Published var customTimerMinutes: Double = 5
    
    // Notes
    @Published var notes: [NoteItem] = []
    @Published var editingNoteIndex: Int? = nil
    @Published var hoveringNoteIndex: Int? = nil
    @Published var isSyncingNotes: Bool = false
    
    // Wi-Fi
    @Published var wifiSSID: String = "Wi-Fi"
    
    // Settings
    @Published var pinnedWidgets: [String] = ["performance", "alarm", "pomodoro"] { didSet { saveSettings() } }
    @Published var backgroundStyle: BackgroundStyle = .liquidGlass { didSet { saveSettings() } }
    @Published var islandColor: Color = .black {
        didSet { saveSettings() }
    }
    @Published var showCameraPreview: Bool = false { didSet { saveSettings() } }
    @Published var language: AppLanguage = .spanish { didSet { saveSettings() } }
    @Published var showSpotifyInstallPrompt: Bool = false
    @Published var accentColor: Color = .white {
        didSet { saveSettings() }
    }
    @Published var showClock: Bool = true { didSet { saveSettings() } }
    @Published var showWidgetPicker: Bool = false
    
    // Alarms & Alerts
    @Published var isAlarmRinging: Bool = false
    @Published var activeAlarmLabel: String = ""
    @Published var isPomodoroRinging: Bool = false
    private var alarmSound: NSSound? = NSSound(named: "Glass")
    
    // Pomodoro Persistence & Status
    
    // Persistence Keys
    private let kBackgroundStyle = "kIslandBackgroundStyle"
    private let kIslandColor = "kIslandColor"
    private let kAccentColor = "kAccentColor"
    private let kPinnedWidgets = "kPinnedWidgets"
    private let kShowClock = "kShowClock"
    private let kLanguage = "kLanguage"
    

    
    // Clipboard
    @Published var clipboardHistory: [String] = []
    private var lastChangeCount: Int = 0
    
    // Weather removed
    
    // System Monitor
    @Published var cpuUsage: Double = 0
    @Published var ramUsage: Double = 0
    @Published var systemTemp: Double = 42.0
    @Published var memoryTotal: Double = 16.0 // GB
    @Published var memoryUsed: Double = 8.0 // GB
    
    // SSD Monitor
    @Published var diskFree: String = "-- GB"
    @Published var diskUsedPercentage: Double = 0.0
    
    // Detailed WiFi
    @Published var wifiSignal: Int = 0
    @Published var wifiSpeed: Int = 0
    
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
    @Published var pomodoroLabel: String = ""
    @Published var workDuration: TimeInterval = 25 * 60
    @Published var breakDuration: TimeInterval = 5 * 60
    
    private var collapseTimer: Timer?

    init() {
        self.mode = .compact
        self.isExpanded = false
        
        loadSettings()
        
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
        
        // Slower timer for Calendar (every 10 mins)
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refreshCalendar()
        }
        
        // Timer for Visualizer Bars
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying {
                self.bars = self.bars.map { _ in CGFloat.random(in: 6...28) }
            }
        }
        
    // Timer to refresh status (Headphones, WiFi, etc) - Less frequent to avoid lag
    Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
        self?.refreshBluetoothDevices()
        self?.refreshWiFiStatus()
    }
    
    // Timer for Alarms (every second check, but careful with efficiency)
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.checkAlarms()
    }
    
    // Load Alarms
    loadAlarms()
        
        // Initial refresh (delayed to not block startup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.requestLocationPermission()
            self?.refreshBluetoothDevices()
            self?.refreshWiFiStatus()
            self?.refreshNotes()
            self?.refreshCalendar()
        }
        
        // System Performance Monitor
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshSystemPerformance()
            self?.refreshDiskSpace()
        }
    }
    
    private var locationManager: CLLocationManager?
    
    func requestLocationPermission() {
        locationManager = CLLocationManager()
        locationManager?.requestWhenInUseAuthorization()
    }
    
    func refreshDiskSpace() {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let capacity = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let totalGB = Double(capacity) / 1_000_000_000
                let freeGB = Double(available) / 1_000_000_000
                let usedRatio = (totalGB - freeGB) / totalGB
                
                DispatchQueue.main.async {
                    self.diskFree = String(format: "%.0f GB", freeGB)
                    self.diskUsedPercentage = usedRatio
                }
            }
        } catch {
            print("Error reading disk space: \(error)")
        }
    }
    
    func refreshSystemPerformance() {
        // Mock CPU/RAM for now, as real access needs specific permissions or complex shell parsing
        // We'll use a realistic random walk for the UI demo
        DispatchQueue.main.async {
            self.cpuUsage = (self.cpuUsage * 0.7) + (Double.random(in: 5...45) * 0.3)
            self.memoryUsed = (self.memoryUsed * 0.95) + (Double.random(in: 4...12) * 0.05)
            self.ramUsage = (self.memoryUsed / self.memoryTotal) * 100
            self.systemTemp = (self.systemTemp * 0.9) + (Double.random(in: 40...75) * 0.1)
        }
    }
    
    func refreshWiFiStatus() {
        // Use CoreWLAN only - it's fast and doesn't block
        let client = CWWiFiClient.shared()
        if let interface = client.interface() {
            let ssid = interface.ssid()
            let rssi = interface.rssiValue()
            let rate = interface.transmitRate()
            let powerOn = interface.powerOn()
            
            DispatchQueue.main.async {
                if let ssid = ssid, !ssid.isEmpty {
                    self.wifiSSID = ssid
                } else if powerOn {
                    self.wifiSSID = "WiFi Conectado"
                } else {
                    self.wifiSSID = "WiFi Apagado"
                }
                self.wifiSignal = rssi
                self.wifiSpeed = Int(rate)
            }
        } else {
            DispatchQueue.main.async {
                self.wifiSSID = "Sin WiFi"
                self.wifiSignal = 0
                self.wifiSpeed = 0
            }
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
        // Optimistic Update
        let tempID = UUID().uuidString
        let newNote = NoteItem(id: tempID, content: "Nueva Nota de Dynamic Island")
        notes.insert(newNote, at: 0)
        
        // Select it for editing immediately
        setMode(.notes)
        isExpanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.editingNoteIndex = 0
        }
        
        // Background sync
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Notes\" to make new note with properties {body:\"Nueva Nota de Dynamic Island\"}"
            self.executeAppleScript(script)
            DispatchQueue.main.async {
                self.refreshNotes()
            }
        }
    }
    
    func deleteNote(at index: Int) {
        guard notes.indices.contains(index) else { return }
        let note = notes[index]
        
        // Optimistic Update
        notes.remove(at: index)
        if editingNoteIndex == index { editingNoteIndex = nil }
        
        // Background sync
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Notes\" to delete note id \"\(note.id)\""
            self.executeAppleScript(script)
            DispatchQueue.main.async {
                self.refreshNotes()
            }
        }
    }

    func saveNote(at index: Int, newContent: String) {
        guard notes.indices.contains(index) else { return }
        
        // Optimistic Update is already handled by Binding in UI
        let noteID = notes[index].id
        let safeContent = newContent.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>") // Preserve newlines
        
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Notes\" to set body of note id \"\(noteID)\" to \"<div>\(safeContent)</div>\""
            self.executeAppleScript(script)
            DispatchQueue.main.async {
                self.refreshNotes()
            }
        }
    }
    
    func openNotesApp() {
        let script = "tell application \"Notes\" to activate"
        executeAppleScript(script)
    }

    func showNotification(_ text: String) {
        let script = "display notification \"\(text)\" with title \"Dynamic Island\" sound name \"Glass\""
        executeAppleScript(script)
    }
    
    func toggleExpand() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
    
    func expand() {
        guard !isExpanded else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            isExpanded = true
        }
        cancelCollapseTimer()
        refreshVolume()
    }
    
    func collapse() {
        guard isExpanded else { return }
        lastCollapseTime = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            isExpanded = false
        }
    }
    
    func setMode(_ newMode: IslandMode, autoCollapse: Bool = true) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            mode = newMode
            if newMode == .battery {
                isExpanded = true
            }
            if newMode == .idle {
                isExpanded = false
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
    
    func setMusicVolume(_ level: Float) {
        self.appVolume = Double(level)
        let vol = Int(level * 100)
        let target = (currentPlayer == "Spotify" || currentPlayer == "Music") ? currentPlayer : "Spotify"
        let script = "tell application \"\(target)\" to set sound volume to \(vol)"
        executeAppleScript(script)
    }
    
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
        let script = "output volume of (get volume settings)"
        if let output = executeAppleScript(script), let vol = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            DispatchQueue.main.async {
                self.volume = Double(vol) / 100.0
            }
        }
    }
    
    // MARK: - System Control (Brightness & Volume)
    
    
    func setSystemVolume(_ level: Float) {
        self.volume = Double(level)
        let script = "set volume output volume \(Int(level * 100))"
        executeAppleScript(script)
    }
    
        
    
    // Helper to interact with IOKit for brightness (simplified)
    private func IOODServiceSetValue(_ service: io_object_t, _ key: CFString!, _ value: Float) {
        // In a real App Store app this uses CoreDisplay. 
        // For this local build, we rely on the generic IODisplay parameters if available.
        // Since accessing IOKit directly from Swift can be verbose, we'll assume the user
        // understands this might not work on all external monitors without DDC/CI tools.
        // For built-in displays, this usually works via IODisplayFloatParameters.
        
        let header = "IODisplayParameters" as CFString
        IORegistryEntrySetCFProperty(service, header, [key: value] as CFDictionary)
    }

    // MARK: - Pomodoro Customization
    func setPomodoroDuration(_ minutes: Int) {
        if pomodoroMode == .work {
            workDuration = TimeInterval(minutes * 60)
        } else {
            breakDuration = TimeInterval(minutes * 60)
        }
        pomodoroRemaining = TimeInterval(minutes * 60)
        isPomodoroRunning = false
    }

    // Bluetooth Control (Native)
    
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
        // Return to compact (non-expanded) after 7s of inactivity
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.isHovering && !self.isPlaying {
                withAnimation(.spring()) {
                    self.isExpanded = false
                }
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
        if ["Meeting", "Clipboard", "Calendar", "Pomodoro"].contains(named) {
            withAnimation(.spring()) {
                selectedApp = named
                isExpanded = true // Force expand to show contextual widget
                // Update active category if needed
                if ["Meeting", "Clipboard", "Pomodoro", "Calendar"].contains(named) { activeCategory = "Favoritos" }
            }
            return
        }
        
        if named == "Settings" {
            withAnimation(.spring()) {
                activeCategory = "Configuración"
                selectedApp = "Settings"
            }
            return
        }
        
        // External apps: launch immediately and close island
        launchApp(named: named)
        withAnimation { 
            isExpanded = false 
            selectedApp = nil
        }
        setMode(.compact)
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
    
    @discardableResult
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
    }

    // Fallback to system_profiler if ioreg is empty
    func refreshBluetoothDevices() {
        DispatchQueue.global(qos: .background).async {
            var devices: [BluetoothDevice] = []
            
            // Use IOBluetooth to get connected devices with battery info
            if let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
                for device in pairedDevices {
                    // Only include connected devices
                    guard device.isConnected() else { continue }
                    
                    let name = device.name ?? "Dispositivo"
                    
                    // Try to get battery from IOBluetooth registry
                    var batteryLevel: Int? = nil
                    
                    // Get battery from the device's service record if available
                    // This uses a workaround through AppleScript for HFP battery
                    let batteryScript = """
                    do shell script "ioreg -r -c IOBluetoothDevice 2>/dev/null | grep -A 30 '\(name)' | grep -i battery | head -1 | sed 's/.*= //' | tr -d '[:space:]'"
                    """
                    if let result = self.executeAppleScript(batteryScript),
                       let level = Int(result) {
                        batteryLevel = level
                    }
                    
                    devices.append(BluetoothDevice(
                        id: UUID().uuidString,
                        name: name,
                        isConnected: true,
                        batteryPercentage: batteryLevel
                    ))
                }
            }
            
            // If IOBluetooth didn't find devices, fallback to system_profiler
            if devices.isEmpty {
                let task = Process()
                task.launchPath = "/usr/sbin/system_profiler"
                task.arguments = ["SPBluetoothDataType", "-json"]
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice
                
                do {
                    try task.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let typeData = json["SPBluetoothDataType"] as? [[String: Any]] {
                        
                        for controller in typeData {
                            if let connectedDevices = controller["device_connected"] as? [[String: Any]] {
                                for deviceDict in connectedDevices {
                                    for (name, properties) in deviceDict {
                                        var batteryLevel: Int? = nil
                                        
                                        if let props = properties as? [String: Any] {
                                            if let mainBat = props["device_batteryLevelMain"] as? String {
                                                batteryLevel = Int(mainBat.replacingOccurrences(of: "%", with: ""))
                                            } else if let caseBat = props["device_batteryLevelCase"] as? String {
                                                batteryLevel = Int(caseBat.replacingOccurrences(of: "%", with: ""))
                                            } else if let leftBat = props["device_batteryLevelLeft"] as? String {
                                                batteryLevel = Int(leftBat.replacingOccurrences(of: "%", with: ""))
                                            } else if let rightBat = props["device_batteryLevelRight"] as? String {
                                                batteryLevel = Int(rightBat.replacingOccurrences(of: "%", with: ""))
                                            }
                                        }
                                        
                                        devices.append(BluetoothDevice(id: UUID().uuidString, name: name, isConnected: true, batteryPercentage: batteryLevel))
                                    }
                                }
                            }
                        }
                    }
                } catch {}
            }
            
            DispatchQueue.main.async {
                self.bluetoothDevices = devices
                
                if let firstHeadphone = devices.first(where: { $0.batteryPercentage != nil }) {
                    self.headphoneName = firstHeadphone.name
                    self.headphoneBattery = firstHeadphone.batteryPercentage
                } else if let first = devices.first {
                    self.headphoneName = first.name
                    self.headphoneBattery = nil
                } else {
                    self.headphoneName = nil
                    self.headphoneBattery = nil
                }
            }
        }
    }
    
    func checkSpotifyInstalled() -> Bool {
        if let _ = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            return true
        }
        return false
    }

    func installSpotify(via: String) {
        if via == "brew" {
            let script = "tell application \"Terminal\" to do script \"brew install --cask spotify\""
            executeAppleScript(script)
            executeAppleScript("tell application \"Terminal\" to activate")
        } else {
            // App Store redirect (Spotify is usually not in Mac App Store in all regions, but we can redirect to web or try appstore link)
            if let url = URL(string: "https://www.spotify.com/download/mac/") {
                NSWorkspace.shared.open(url)
            }
        }
        showSpotifyInstallPrompt = false
    }

    func launchApp(named: String) {
        let appName: String = {
            switch named {
            case "Wsp": return "WhatsApp"
            case "Chrome": return "Google Chrome"
            case "Calendar": return "Calendario"
            default: return named
            }
        }()
        
        if appName == "Finder" {
            if let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
                NSWorkspace.shared.open(finderURL)
            } else {
                let fallbackURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
                NSWorkspace.shared.open(fallbackURL)
            }
            return
        }

        let bundleID: String? = {
            switch appName {
            case "Spotify": return "com.spotify.client"
            case "Notes": return "com.apple.Notes"
            case "Calendar": return "com.apple.iCal"
            case "Mail": return "com.apple.mail"
            case "Safari": return "com.apple.Safari"
            case "FaceTime": return "com.apple.FaceTime"
            case "Music": return "com.apple.Music"
            default: return nil
            }
        }()
        
        if let bid = bundleID {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                NSWorkspace.shared.open(appURL)
                return
            } else if bid == "com.spotify.client" {
                withAnimation {
                    self.showSpotifyInstallPrompt = true
                    self.isExpanded = true
                }
                return
            }
        }
        
        // Fallback to searching /Applications and /System/Applications
        let searchPaths = ["/Applications", "/System/Applications", "/System/Library/CoreServices"]
        for path in searchPaths {
            let appPath = "\(path)/\(appName).app"
            if FileManager.default.fileExists(atPath: appPath) {
                NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
                return
            }
        }
        
        // Final fallback: try to run it using openApplication (modern)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) ?? 
                    NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.\(appName.lowercased())") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    private func startMockUpdates() {
        // No mocks for now
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
    
    // MARK: - Weather Removed
    
    // MARK: - Calendar
    func refreshCalendar() {
        let completion: (Bool, Error?) -> Void = { granted, error in
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
        
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents(completion: completion)
        } else {
            eventStore.requestAccess(to: .event, completion: completion)
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
        pomodoroRemaining = (pomodoroMode == .work ? workDuration : breakDuration)
        setMode(.compact) // Return to normal header
    }
    
    private func updatePomodoro() {
        guard isPomodoroRunning else { return }
        if pomodoroRemaining > 0 {
            pomodoroRemaining -= 1
        } else {
            if pomodoroMode == .work {
                pomodoroCycles += 1
                pomodoroMode = .shortBreak
                pomodoroRemaining = breakDuration
                showNotification("¡Enfoque terminado! Descanso.")
            } else {
                pomodoroMode = .work
                pomodoroRemaining = workDuration
                showNotification("¡Descanso terminado! A trabajar.")
            }
            isPomodoroRunning = false
            triggerPomodoroAlarm()
        }
    }
    
    private func triggerPomodoroAlarm() {
        isPomodoroRinging = true
        isExpanded = true
        
        alarmSound?.loops = true
        alarmSound?.play()
        
        // Auto-stop after 1 minute
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            if self?.isPomodoroRinging == true {
                self?.stopPomodoroAlarm()
            }
        }
    }
    
    func stopPomodoroAlarm() {
        isPomodoroRinging = false
        alarmSound?.stop()
    }
    
    func stopAlarm() {
        isAlarmRinging = false
        alarmSound?.stop()
    }
            // MARK: - Persistence
    
    func saveSettings() {
        UserDefaults.standard.set(backgroundStyle.rawValue, forKey: kBackgroundStyle)
        UserDefaults.standard.set(pinnedWidgets, forKey: kPinnedWidgets)
        UserDefaults.standard.set(showClock, forKey: kShowClock)
        UserDefaults.standard.set(showCameraPreview, forKey: "kShowCameraPreview")
        UserDefaults.standard.set(language.rawValue, forKey: kLanguage)
        
        if let islandHex = islandColor.toHex() {
            UserDefaults.standard.set(islandHex, forKey: kIslandColor)
        }
        if let accentHex = accentColor.toHex() {
            UserDefaults.standard.set(accentHex, forKey: kAccentColor)
        }
    }
    
    func loadSettings() {
        if let styleStr = UserDefaults.standard.string(forKey: kBackgroundStyle),
           let style = BackgroundStyle(rawValue: styleStr) {
            self.backgroundStyle = style
        }
        
        if let widgets = UserDefaults.standard.array(forKey: kPinnedWidgets) as? [String] {
            self.pinnedWidgets = widgets
        }
        
        if UserDefaults.standard.object(forKey: kShowClock) != nil {
            self.showClock = UserDefaults.standard.bool(forKey: kShowClock)
        }
        
        if UserDefaults.standard.object(forKey: "kShowCameraPreview") != nil {
            self.showCameraPreview = UserDefaults.standard.bool(forKey: "kShowCameraPreview")
        }
        
        if let langRaw = UserDefaults.standard.string(forKey: kLanguage),
           let lang = AppLanguage(rawValue: langRaw) {
            self.language = lang
        }
        
        if let islandHex = UserDefaults.standard.string(forKey: kIslandColor) {
            self.islandColor = Color(hex: islandHex)
        }
        
        if let accentHex = UserDefaults.standard.string(forKey: kAccentColor) {
            self.accentColor = Color(hex: accentHex)
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
            case .compact: return 500
            case .music: return 450
            case .timer: return 350
            case .notes: return 500 // Match dashboard width
            case .productivity: return 500
            default: return 320
            }
        } else {
            // Adaptive compact width based on notch
            let baseWidth: CGFloat
            if hasNotch {
                baseWidth = notchWidth
            } else {
                baseWidth = 180
            }
            
            switch mode {
            case .idle: return hasNotch ? notchWidth : 180
            case .compact: return baseWidth
            case .music: return baseWidth + 40
            case .battery: return hasNotch ? baseWidth : 120
            case .volume: return hasNotch ? baseWidth : 200
            case .timer: return baseWidth // Standard width
            case .notes: return baseWidth // Standard width (was 160)
            case .productivity: return baseWidth
            }
        }
    }
    
    func heightForMode(_ mode: IslandMode, isExpanded: Bool) -> CGFloat {
        if isExpanded {
            switch mode {
            case .compact: return 520
            case .music: return 280
            case .battery: return 200
            case .volume: return 200
            case .timer: return 520
            case .notes: return 520
            case .productivity: return 520
            default: return 520
            }
        } else {
            // Minimized height to hug text (notch + 36)
            return hasNotch ? notchHeight + 36 : 45
        }
    }
    func toggleWidget(_ id: String) {
        if pinnedWidgets.contains(id) {
            pinnedWidgets.removeAll { $0 == id }
        } else {
            pinnedWidgets.append(id)
        }
    }

    // MARK: - Alarm Logic
    struct Alarm: Identifiable, Codable {
        var id = UUID()
        var time: Date
        var label: String
        var isEnabled: Bool
        var repeatDays: Set<Int>
    }

    @Published var alarms: [Alarm] = [] {
        didSet { saveAlarms() }
    }
    private let kAlarms = "kAlarms"

    func addAlarm(time: Date, label: String, repeatDays: Set<Int>) {
        let newAlarm = Alarm(time: time, label: label, isEnabled: true, repeatDays: repeatDays)
        alarms.append(newAlarm)
        alarms.sort { $0.time < $1.time }
    }

    func deleteAlarm(id: UUID) {
        alarms.removeAll { $0.id == id }
    }

    func toggleAlarm(id: UUID) {
        if let index = alarms.firstIndex(where: { $0.id == id }) {
            alarms[index].isEnabled.toggle()
        }
    }

    func updateAlarm(id: UUID, time: Date, label: String, repeatDays: Set<Int>) {
        if let index = alarms.firstIndex(where: { $0.id == id }) {
            alarms[index].time = time
            alarms[index].label = label
            alarms[index].repeatDays = repeatDays
            alarms.sort { $0.time < $1.time }
        }
    }

    func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: kAlarms)
        }
    }

    func loadAlarms() {
        if let saved = UserDefaults.standard.data(forKey: kAlarms),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: saved) {
            alarms = decoded
        }
    }

    func checkAlarms() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second, .weekday], from: now)
        
        for alarm in alarms where alarm.isEnabled {
            let alarmComponents = calendar.dateComponents([.hour, .minute], from: alarm.time)
            
            // Check matching time (Hour & Minute)
            if components.hour == alarmComponents.hour &&
               components.minute == alarmComponents.minute {
                
                // Trigger only at 0 seconds
                if let sec = components.second, sec == 0 {
                    // Check Repetition
                    let currentWeekday = components.weekday! // 1-7
                    if alarm.repeatDays.isEmpty || alarm.repeatDays.contains(currentWeekday) {
                        triggerAlarm(alarm)
                    }
                }
            }
        }
    }
    
    private func triggerAlarm(_ alarm: Alarm) {
        print("🔔 ALARM TRIGGERED: \(alarm.label)")
        activeAlarmLabel = alarm.label.isEmpty ? "Alarma" : alarm.label
        isAlarmRinging = true
        activeCategory = "widgets"
        isExpanded = true
        
        showNotification("Alarma: \(activeAlarmLabel)")
        
        // Loop sound for 60 seconds
        alarmSound?.loops = true
        alarmSound?.play()
        
        // Auto-stop after 1 minute if user hasn't stopped it
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            if self?.isAlarmRinging == true {
                self?.stopAlarm()
            }
        }
        
        // If not repeating, disable it
        if alarm.repeatDays.isEmpty {
            if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
                alarms[index].isEnabled = false
            }
        }
    }
    
    func l(_ key: String) -> String {
        let dict: [String: [AppLanguage: String]] = [
            "ESTILO": [.spanish: "ESTILO", .english: "STYLE"],
            "COLOR DEL FONDO (SOLIDO)": [.spanish: "COLOR DEL FONDO (SÓLIDO)", .english: "BACKGROUND COLOR (SOLID)"],
            "Personalizado": [.spanish: "Personalizado", .english: "Custom"],
            "COLOR DE ACENTO": [.spanish: "COLOR DE ACENTO", .english: "ACCENT COLOR"],
            "IDIOMA": [.spanish: "IDIOMA", .english: "LANGUAGE"],
            "Cerrar Island": [.spanish: "Cerrar Island", .english: "Close Island"],
            "ACCESO RÁPIDO": [.spanish: "ACCESO RÁPIDO", .english: "QUICK ACCESS"],
            "WIDGETS DEL SISTEMA": [.spanish: "WIDGETS DEL SISTEMA", .english: "SYSTEM WIDGETS"],
            "LISTO": [.spanish: "LISTO", .english: "DONE"],
            "AÑADIR": [.spanish: "AÑADIR", .english: "ADD"],
            "ALARMAS": [.spanish: "ALARMAS", .english: "ALARMS"],
            "VISTA PREVIA DE CÁMARA": [.spanish: "VISTA PREVIA DE CÁMARA", .english: "CAMERA PREVIEW"],
            "Cámara Apagada": [.spanish: "Cámara Apagada", .english: "Camera Off"],
            "PRÓXIMO": [.spanish: "PRÓXIMO", .english: "NEXT EVENT"],
            "Sin eventos": [.spanish: "Sin eventos", .english: "No events"],
            "MIS NOTAS": [.spanish: "MIS NOTAS", .english: "MY NOTES"],
            "EDITOR DE NOTAS": [.spanish: "EDITOR DE NOTAS", .english: "NOTE EDITOR"],
            "Mis Notas": [.spanish: "Mis Notas", .english: "My Notes"],
            "TEMPORIZADOR": [.spanish: "TEMPORIZADOR", .english: "TIMER"],
            "Nueva Nota de Dynamic Island": [.spanish: "Nueva Nota de Dynamic Island", .english: "New Dynamic Island Note"],
            "PAUSAR": [.spanish: "PAUSAR", .english: "PAUSE"],
            "Spotify no instalado": [.spanish: "Spotify no instalado", .english: "Spotify not installed"],
            "Parece que no tienes Spotify. ¿Quieres instalarlo?": [.spanish: "Parece que no tienes Spotify. ¿Quieres instalarlo?", .english: "It looks like you don't have Spotify. Do you want to install it?"],
            "Instalar por Brew": [.spanish: "Instalar por Brew", .english: "Install via Brew"],
            "Ir a la Web": [.spanish: "Ir a la Web", .english: "Go to Web"],
            "Cancelar": [.spanish: "Cancelar", .english: "Cancel"],
            "INICIAR": [.spanish: "INICIAR", .english: "START"],
            "ENFOQUE": [.spanish: "ENFOQUE", .english: "FOCUS"],
            "PORTAPAPELES": [.spanish: "PORTAPAPELES", .english: "CLIPBOARD"],
            "PRÓXIMO EVENTO": [.spanish: "PRÓXIMO EVENTO", .english: "NEXT EVENT"],
            "TU AGENDA": [.spanish: "TU AGENDA", .english: "YOUR AGENDA"],
            "NOTAS RÁPIDAS": [.spanish: "NOTAS RÁPIDAS", .english: "QUICK NOTES"],
            "Copia algo para empezar...": [.spanish: "Copia algo para empezar...", .english: "Copy something to start..."],
            "No hay eventos próximos": [.spanish: "No hay eventos próximos", .english: "No upcoming events"],
            "Mostrar Reloj": [.spanish: "Mostrar Reloj", .english: "Show Clock"],
            "CONFIGURACIÓN DE LA ISLA": [.spanish: "CONFIGURACIÓN DE LA ISLA", .english: "ISLAND SETTINGS"],
            "Color Fondo": [.spanish: "Color Fondo", .english: "Island Color"],
            "CPU": [.spanish: "CPU", .english: "CPU"],
            "RAM": [.spanish: "Memoria RAM", .english: "Memory RAM"],
            "TEMP": [.spanish: "Temperatura", .english: "Temperature"],
            "SSD": [.spanish: "Disco SSD", .english: "SSD Drive"],
            "Sin alarmas": [.spanish: "Sin alarmas", .english: "No alarms"],
            "VACÍO": [.spanish: "VACÍO", .english: "EMPTY"],
            "Alarma": [.spanish: "Alarma", .english: "Alarm"],
            "ENFOQUE POMODORO": [.spanish: "ENFOQUE POMODORO", .english: "POMODORO FOCUS"],
            "TRABAJANDO...": [.spanish: "TRABAJANDO...", .english: "WORKING..."],
            "DETENIDO": [.spanish: "DETENIDO", .english: "STOPPED"],
            "Sistema macOS": [.spanish: "Sistema macOS", .english: "macOS System"],
            "BLUETOOTH": [.spanish: "BLUETOOTH", .english: "BLUETOOTH"],
            "Favoritos": [.spanish: "Favoritos", .english: "Favorites"],
            "Recientes": [.spanish: "Recientes", .english: "Recents"],
            "Dispositivos": [.spanish: "Dispositivos", .english: "Devices"],
            "Utilidades": [.spanish: "Utilidades", .english: "Utilities"],
            "Configuración": [.spanish: "Configuración", .english: "Settings"],
            "APPS": [.spanish: "APLICACIONES", .english: "APPLICATIONS"],
            "FAVORITOS": [.spanish: "FAVORITOS", .english: "FAVORITES"],
            "RECIENTES": [.spanish: "RECIENTES", .english: "RECENTS"],
            "DISPOSITIVOS": [.spanish: "DISPOSITIVOS", .english: "DEVICES"],
            "UTILIDADES": [.spanish: "UTILIDADES", .english: "UTILITIES"],
            "CONFIGURACIÓN": [.spanish: "CONFIGURACIÓN", .english: "SETTINGS"],
            "Apps": [.spanish: "Apps", .english: "Apps"],
            "Connect": [.spanish: "Conectar", .english: "Connect"],
            "Clip": [.spanish: "Clip", .english: "Clip"],
            "Nook": [.spanish: "Rincón", .english: "Nook"],
            "Media": [.spanish: "Media", .english: "Media"],
            "Focus": [.spanish: "Enfoque", .english: "Focus"],
            "Setup": [.spanish: "Ajustes", .english: "Setup"],
            "MODO PRODUCTIVIDAD": [.spanish: "MODO PRODUCTIVIDAD", .english: "PRODUCTIVITY MODE"],
            "BLOQUEADOR DE DISTRACCIONES": [.spanish: "BLOQUEADOR DE DISTRACCIONES", .english: "DISTRACTION BLOCKER"],
            "Notas": [.spanish: "Notas", .english: "Notes"],
            "Timer": [.spanish: "Temporizador", .english: "Timer"],
            "MINUTOS": [.spanish: "MINUTOS", .english: "MINUTES"],
            "NOMBRE DE LA SESIÓN": [.spanish: "NOMBRE DE LA SESIÓN", .english: "SESSION NAME"],
            "PERSONALIZADO:": [.spanish: "PERSONALIZADO:", .english: "CUSTOM:"],
            "FIJAR": [.spanish: "FIJAR", .english: "SET"],
            "BLOQUEO DE DISTRACCIONES:": [.spanish: "BLOQUEO DE DISTRACCIONES:", .english: "DISTRACTION BLOCK:"],
            "ACTIVO": [.spanish: "ACTIVO", .english: "ACTIVE"],
            "INACTIVO": [.spanish: "INACTIVO", .english: "INACTIVE"],
            "No reproduciendo": [.spanish: "No reproduciendo", .english: "Not playing"],
            "WiFi Conectado": [.spanish: "WiFi Conectado", .english: "WiFi Connected"],
            "SEÑAL": [.spanish: "SEÑAL", .english: "SIGNAL"],
            "VELOCIDAD": [.spanish: "VELOCIDAD", .english: "SPEED"],
            "DISPOSITIVOS BLUETOOTH": [.spanish: "DISPOSITIVOS BLUETOOTH", .english: "BLUETOOTH DEVICES"],
            "No hay dispositivos conectados": [.spanish: "No hay dispositivos conectados", .english: "No devices connected"],
            "HISTORIAL DE PORTAPAPELES": [.spanish: "HISTORIAL DE PORTAPAPELES", .english: "CLIPBOARD HISTORY"],
            "LIMPIAR": [.spanish: "LIMPIAR", .english: "CLEAR"],
            "Vacío": [.spanish: "Vacío", .english: "Empty"],
            "Calendario": [.spanish: "Calendario", .english: "Calendar"],
            "Multitarea rápida": [.spanish: "Multitarea rápida", .english: "Quick multitasking"],
            "WiFi Tooltip": [.spanish: "Estos valores se leen directamente del hardware Wi-Fi (CoreWLAN) en tiempo real, sin realizar descargas.\n\n• Velocidad: Tasa de enlace (TX Rate).\n• Señal: Potencia (RSSI).", .english: "These values are read directly from the Wi-Fi hardware (CoreWLAN) in real-time, without downloads.\n\n• Speed: Link Rate (TX Rate).\n• Signal: Power (RSSI)."],
            "Signal Tooltip": [.spanish: "dBm (decibelios-milivatio): mide la potencia de la señal recibida.\n\n• -30 a -60: Excelente\n• -60 a -75: Aceptable\n• -80 o menos: Mala", .english: "dBm (decibel-milliwatts): measures the power level of the received signal.\n\n• -30 to -60: Excellent\n• -60 to -75: Aceptable\n• -80 or less: Poor"],
            "Speed Tooltip": [.spanish: "Mbps (Megabits por segundo):\n\nEs la tasa de transferencia teórica (TX Rate) entre tu Mac y el Router, NO la velocidad de Internet.", .english: "Mbps (Megabits per second):\n\nThis is the theoretical transfer rate (TX Rate) between your Mac and the Router, NOT Internet speed."],
            "SUELTA ARCHIVOS AQUÍ": [.spanish: "SUELTA ARCHIVOS AQUÍ", .english: "DROP FILES HERE"],
            "PAUSA": [.spanish: "PAUSA", .english: "PAUSE"],
            "TRABAJO": [.spanish: "TRABAJO", .english: "WORK"],
            "DESCANSO": [.spanish: "DESCANSO", .english: "REST"],
            "WiFi Apagado": [.spanish: "WiFi Apagado", .english: "WiFi Off"],
            "Sin WiFi": [.spanish: "Sin WiFi", .english: "No WiFi"],
            "MUTE": [.spanish: "SILENCIO", .english: "MUTE"],
            "Productividad": [.spanish: "Productividad", .english: "Productivity"],
            "Conectando con iCloud...": [.spanish: "Conectando con iCloud...", .english: "Connecting to iCloud..."],
            "SINCRONIZADO": [.spanish: "SINCRONIZADO", .english: "SYNCED"],
            "No hay alarmas configuradas": [.spanish: "No hay alarmas configuradas", .english: "No alarms configured"],
            "ALARMA": [.spanish: "ALARMA", .english: "ALARM"],
            "DETENER": [.spanish: "DETENER", .english: "STOP"],
            "Conectado": [.spanish: "Conectado", .english: "Connected"],
            "Desconectar": [.spanish: "Desconectar", .english: "Disconnect"],
            "Buscando dispositivos...": [.spanish: "Buscando dispositivos...", .english: "Searching for devices..."],
            "Wi-Fi": [.spanish: "Wi-Fi", .english: "Wi-Fi"],
            "Información de ": [.spanish: "Información de ", .english: "Information of "],
            "POMODORO": [.spanish: "POMODORO", .english: "POMODORO"],
            "Focus...": [.spanish: "Enfoque...", .english: "Focus..."],
            "Música": [.spanish: "Música", .english: "Music"],
            "DESCANSO TERMINADO": [.spanish: "DESCANSO TERMINADO", .english: "REST FINISHED"],
            "ENFOQUE TERMINADO": [.spanish: "ENFOQUE TERMINADO", .english: "FOCUS FINISHED"],
            "¡A trabajar!": [.spanish: "¡A trabajar!", .english: "Get to work!"],
            "¡Buen trabajo!": [.spanish: "¡Buen trabajo!", .english: "Great job!"],
            " más...": [.spanish: " más...", .english: " more..."],
            "Escribe tu nota aquí...": [.spanish: "Escribe tu nota aquí...", .english: "Write your note here..."],
            "Etiqueta": [.spanish: "Etiqueta", .english: "Label"],
            "Mesh Gradient": [.spanish: "Gradiante Mesh", .english: "Mesh Gradient"],
            "Glassmorphism": [.spanish: "Efecto Vidrio", .english: "Glassmorphism"],
            "Solid Color": [.spanish: "Color Sólido", .english: "Solid Color"],
            "Español": [.spanish: "Español", .english: "Spanish"],
            "English": [.spanish: "Inglés", .english: "English"],
            "UNIRSE": [.spanish: "UNIRSE", .english: "JOIN"]
        ]
        
        return dict[key]?[language] ?? key
    }
}

// MARK: - Color Hex Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        // Simple conversion for NSColor backed Colors
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(a * 255), lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
