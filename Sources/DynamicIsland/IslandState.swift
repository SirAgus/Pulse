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
    @Published var isHovering: Bool = false {
        didSet {
            if isHovering {
                cancelCollapseTimer()
                if mode == .idle {
                    setMode(.compact, autoCollapse: false)
                }
                if !isExpanded {
                    expand()
                }
            } else {
                // Don't start collapse timer - island stays visible
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
    @Published var activeCategory: String = "apps" {
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
    @Published var pinnedWidgets: [String] = ["performance", "media"] { didSet { saveSettings() } }
    @Published var backgroundStyle: BackgroundStyle = .liquidGlass { didSet { saveSettings() } }
    @Published var islandColor: Color = .black {
        didSet { saveSettings() }
    }
    @Published var accentColor: Color = .white {
        didSet { saveSettings() }
    }
    @Published var showClock: Bool = true { didSet { saveSettings() } }
    @Published var showWidgetPicker: Bool = false
    
    // Meeting Mode
    @Published var isMicMuted: Bool = false
    @Published var isDNDActive: Bool = false
    
    // Persistence Keys
    private let kBackgroundStyle = "kIslandBackgroundStyle"
    private let kIslandColor = "kIslandColor"
    private let kAccentColor = "kAccentColor"
    private let kPinnedWidgets = "kPinnedWidgets"
    private let kShowClock = "kShowClock"
    

    
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
        
        // Initial refresh (delayed to not block startup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.requestLocationPermission()
            self?.refreshBluetoothDevices()
            self?.refreshWiFiStatus()
            self?.refreshNotes()
            self?.refreshCalendar()
            self?.refreshMicStatus()
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
        let script = "tell application \"Notes\" to make new note with properties {body:\"Nueva Nota de Dynamic Island\"}"
        executeAppleScript(script)
        refreshNotes()
        setMode(.notes)
        isExpanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
            isExpanded = false
        }
        // No timer - island stays visible in compact mode
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
    
    @Published var systemBrightness: Float = 0.5
    
    func setSystemVolume(_ level: Float) {
        self.volume = Double(level)
        let script = "set volume output volume \(Int(level * 100))"
        executeAppleScript(script)
    }
    
    func setSystemBrightness(_ level: Float) {
        self.systemBrightness = level
        
        // Use IOREG/DisplayServices to set brightness
        // This is a bridge to CoreDisplay for basic brightness control
        // Note: This often requires private entitlements for full control, but we can try the standard IOKit approach
        
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(0, IOServiceMatching("IODisplayConnect"), &iterator) == kIOReturnSuccess {
            var service: io_object_t = 1
            while service != 0 {
                service = IOIteratorNext(iterator)
                if service != 0 {
                    let key = CFStringCreateWithCString(kCFAllocatorDefault, "IODisplayBrightnessProbe", kCFStringEncodingASCII)
                    IOODServiceSetValue(service, key, level)
                    IOObjectRelease(service)
                }
            }
            IOObjectRelease(iterator)
        }
        
        // 2. Try 'brightness' CLI tool fallback
        let script = "try\ndo shell script \"/usr/local/bin/brightness " + String(level) + "\"\nend try"
        executeAppleScript(script)
        
        // Backup: Brightness via Shortcuts if "Set Brightness" shortcut exists
        // executeAppleScript("tell application \"Shortcuts Events\" to run shortcut \"Set Brightness\" with input \(level)")
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
        pomodoroMode = .work
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
        
        if let bid = bundleID, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            NSWorkspace.shared.open(appURL)
            return
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
    
    // MARK: - Weather Removed
    
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
            // MARK: - Persistence
    
    func saveSettings() {
        UserDefaults.standard.set(backgroundStyle.rawValue, forKey: kBackgroundStyle)
        UserDefaults.standard.set(pinnedWidgets, forKey: kPinnedWidgets)
        UserDefaults.standard.set(showClock, forKey: kShowClock)
        
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
            case .battery: return 120
            case .volume: return 120
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
