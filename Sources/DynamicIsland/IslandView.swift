import SwiftUI
import AppKit

struct IslandView: View {
    @EnvironmentObject var state: IslandState
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Main Island Background with Tap Gesture
            // We use a button-like interaction for the background to correctly handle layering
            RoundedRectangle(cornerRadius: state.isExpanded ? 35 : (state.mode == .idle ? 4 : 15), style: .continuous)
                .fill(state.islandColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    state.toggleExpand()
                }
                .zIndex(0)
            
            // Content Layer (Buttons, text, etc)
            contentForMode(state.mode)
                .opacity(state.mode == .idle ? 0 : 1)
                .allowsHitTesting(true)
                .zIndex(1)
        }
        .frame(
            width: state.widthForMode(state.mode, isExpanded: state.isExpanded),
            height: state.heightForMode(state.mode, isExpanded: state.isExpanded)
        )
        .onHover { hovering in
            state.isHovering = hovering
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: state.mode)
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: state.isExpanded)
        .animation(.spring(), value: state.selectedApp)
    }
    
    @ViewBuilder
    func contentForMode(_ mode: IslandMode) -> some View {
        Group {
            switch mode {
            case .idle:
                EmptyView()
            case .compact:
                if state.isExpanded {
                    expandedDashboardContent
                } else {
                    compactContent
                }
            case .music:
                if state.isExpanded {
                    expandedMusicContent
                } else {
                    compactMusicContent
                }
            case .timer:
                if state.isExpanded {
                    expandedTimerContent
                } else {
                    compactTimerContent
                }
            case .notes:
                if state.isExpanded {
                    expandedNotesContent
                } else {
                    compactNotesContent
                }
            case .battery:
                batteryContent
            case .volume:
                volumeContent
            }
        }
        .foregroundColor(.white)
    }
    
    // MARK: - Subviews
    
    var compactContent: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("Activa")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
    }
    
    var compactMusicContent: some View {
        HStack(spacing: 12) {
            // Artwork / App Icon on the left
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [state.accentColor.opacity(0.3), state.accentColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 24, height: 24)
                
                if let artwork = state.trackArtwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let icon = getAppIcon(for: state.currentPlayer) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2)
            
            // Song Title in the middle
            Text(state.songTitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            
            // Waveform / Headphone Battery on the right
            HStack(spacing: 6) {
                if let battery = state.headphoneBattery {
                    HStack(spacing: 3) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 10))
                        Text("\(battery)%")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.blue)
                    .padding(.trailing, 4)
                }
                
                HStack(alignment: .center, spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange)
                        .frame(width: 2, height: state.isPlaying ? 8 : 4)
                        .offset(y: state.isPlaying ? -1 : 0)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange)
                        .frame(width: 2, height: state.isPlaying ? 14 : 4)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange)
                        .frame(width: 2, height: state.isPlaying ? 10 : 4)
                        .offset(y: state.isPlaying ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.4).repeatForever(), value: state.isPlaying)
            }
        }
        .padding(.horizontal, 15)
    }
    
    // MARK: - Native Timer Views
    
    var compactTimerContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundColor(.orange)
                .font(.system(size: 14, weight: .bold))
            Text(formatTime(state.timerRemaining))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
    }
    
    var expandedTimerContent: some View {
        VStack(spacing: 15) {
            HStack {
                Button(action: { state.showDashboard() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 20))
                        .opacity(0.3)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("TEMPORIZADOR")
                    .font(.system(size: 10, weight: .black))
                    .opacity(0.4)
                Spacer()
                Image(systemName: "timer").foregroundColor(.orange)
            }
            
            Text(formatTime(state.timerRemaining))
                .font(.system(size: 40, weight: .black, design: .monospaced))
            
            HStack(spacing: 15) {
                if state.isTimerRunning {
                    Button(action: { state.stopTimer() }) {
                        Text("PAUSAR")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { state.startTimer(minutes: 5) }) {
                        Text("5m")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.startTimer(minutes: 10) }) {
                        Text("10m")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - Native Notes Views
    
    var compactNotesContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "note.text")
                .foregroundColor(.yellow)
            Text(state.notes.first ?? "Notas")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
    }
    
    var expandedNotesContent: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { state.showDashboard() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 20))
                        .opacity(0.3)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("MIS NOTAS")
                    .font(.system(size: 10, weight: .black))
                    .opacity(0.4)
                Spacer()
                Button(action: { state.addNote() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
            
            ScrollView {
                if state.isSyncingNotes && state.notes.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Sincronizando con iCloud...")
                            .font(.system(size: 10))
                            .opacity(0.4)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(0..<state.notes.count, id: \.self) { index in
                            HStack {
                                if state.editingNoteIndex == index {
                                    TextField("Escribe aquí...", text: Binding(
                                        get: { state.notes[safe: index]?.content ?? "" },
                                        set: { state.notes[index].content = $0 }
                                    ), onCommit: {
                                        state.saveNote(at: index, newContent: state.notes[index].content)
                                        state.editingNoteIndex = nil
                                    })
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.yellow)
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(state.notes[index].content)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text("Nota de Sistema")
                                            .font(.system(size: 10))
                                            .opacity(0.4)
                                    }
                                    .onTapGesture { state.editingNoteIndex = index }
                                    
                                    Spacer()
                                    
                                    Button(action: { state.deleteNote(at: index) }) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(state.editingNoteIndex == index ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(20)
    }
    
    var expandedDashboardContent: some View {
        VStack(spacing: 0) {
            dashboardStatusBar
            dashboardCategorySelector
            
            // Content Area based on Category
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                
                if state.activeCategory == "Dispositivos" {
                    dashboardDevicesGrid
                } else {
                    dashboardAppGrid
                    
                    if state.selectedApp != nil {
                        dashboardContextualWidgets
                    }
                }
            }
            .animation(.spring(), value: state.selectedApp)
            .animation(.spring(), value: state.activeCategory)
            
            Spacer(minLength: 20)
            
            dashboardFooter
        }
    }

    var dashboardAppGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 25) {
                ForEach(getAppsForCategory(state.activeCategory), id: \.id) { app in
                    Button(action: { 
                        state.openApp(named: app.id)
                    }) {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(state.selectedApp == app.id ? app.color.opacity(0.15) : Color.white.opacity(0.05))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(state.selectedApp == app.id ? app.color : Color.white.opacity(0.1), lineWidth: 1.5)
                                    )
                                
                                if let icon = getAppIcon(for: app.name) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                } else {
                                    Image(systemName: app.icon)
                                        .font(.system(size: 26))
                                        .foregroundColor(app.color)
                                }
                                
                                if let badge = app.badge, !badge.isEmpty {
                                    Text(badge)
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                        .offset(x: 22, y: -22)
                                }
                            }
                            
                            Text(app.name)
                                .font(.system(size: 10, weight: state.selectedApp == app.id ? .black : .bold))
                                .foregroundColor(state.selectedApp == app.id ? .white : .white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(25)
        }
        .frame(maxHeight: 280) // Limit height but allow it to be smaller
    }

    var dashboardDevicesGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main Computer info
                deviceRow(
                    name: "MacBook Pro",
                    detail: "Sistema macOS",
                    icon: "laptopcomputer",
                    battery: state.batteryLevel,
                    isCharging: state.isCharging
                )
                
                // Headphones info
                if let name = state.headphoneName, let battery = state.headphoneBattery {
                    deviceRow(
                        name: name,
                        detail: "Audífonos Conectados",
                        icon: "airpodspro",
                        battery: battery,
                        isCharging: false
                    )
                } else {
                    HStack {
                        Image(systemName: "headphones.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.2))
                        VStack(alignment: .leading) {
                            Text("Sin Audífonos")
                                .font(.system(size: 14, weight: .bold))
                            Text("No se detectan dispositivos BT")
                                .font(.system(size: 12))
                                .opacity(0.4)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(18)
                }
                
                // WiFi Info
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "wifi")
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.wifiSSID)
                            .font(.system(size: 14, weight: .bold))
                        Text("Red Wi-Fi Actual")
                            .font(.system(size: 12))
                            .opacity(0.4)
                    }
                    Spacer()
                    Text("Conectado")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(18)
            }
            .padding(25)
        }
        .frame(maxHeight: 280)
    }

    func deviceRow(name: String, detail: String, icon: String, battery: Int, isCharging: Bool) -> some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(state.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                Text(detail)
                    .font(.system(size: 11))
                    .opacity(0.5)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                }
                
                Text("\(battery)%")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 35, height: 16)
                    Capsule()
                        .fill(battery < 20 ? Color.red : (isCharging ? Color.green : Color.white))
                        .frame(width: CGFloat(battery) * 0.35, height: 16)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    var dashboardContextualWidgets: some View {
        Group {
            if let selected = state.selectedApp {
                VStack(spacing: 12) {
                    if selected == "Timer" {
                        timerWidget
                    } else if selected == "Notes" {
                        notesWidget
                    } else if selected == "Settings" {
                        settingsWidget
                    } else {
                        recentInfoWidget(for: selected)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal, 25)
            }
        }
    }

    func recentInfoWidget(for appName: String) -> some View {
        HStack {
            Text("Información de \(appName)")
                .font(.system(size: 12, weight: .bold))
            Spacer()
            Image(systemName: "chevron.right").opacity(0.3)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
    }

    var dashboardFooter: some View {
        Group {
            if state.isPlaying || !state.songTitle.isEmpty {
                Button(action: { state.showMusic() }) {
                    HStack(spacing: 15) {
                        footerArtworkView
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.songTitle)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .lineLimit(1)
                            Text("\(state.artistName) • \(state.currentPlayer)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        footerVisualizer
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.05), Color.black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
            }
        }
    }

    var footerArtworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [state.accentColor.opacity(0.2), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
            
            if let artwork = state.trackArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else if let icon = getAppIcon(for: state.currentPlayer) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(state.accentColor)
                    .font(.system(size: 24))
            }
        }
    }

    var footerVisualizer: some View {
        HStack(spacing: 3) {
            ForEach(0..<state.bars.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(state.accentColor)
                    .frame(width: 3, height: state.bars[i])
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state.bars[i])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    struct AppData {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let badge: String?
    }
    
    func getAppsForCategory(_ cat: String) -> [AppData] {
        switch cat {
        case "Favoritos":
            return [
                AppData(id: "Spotify", name: "Spotify", icon: "play.fill", color: .green, badge: nil),
                AppData(id: "Wsp", name: "WhatsApp", icon: "message.fill", color: .green, badge: state.wspBadge),
                AppData(id: "Slack", name: "Slack", icon: "hash", color: .purple, badge: state.slackBadge),
                AppData(id: "Finder", name: "Finder", icon: "folder.fill", color: .blue, badge: nil)
            ]
        case "Recientes":
            return [
                AppData(id: "Chrome", name: "Google Chrome", icon: "network", color: .blue, badge: nil),
                AppData(id: "Calendar", name: "Calendario", icon: "calendar", color: .red, badge: nil),
                AppData(id: "Notes", name: "Notes", icon: "note.text", color: .yellow, badge: nil)
            ]
        case "Utilidades":
            return [
                AppData(id: "Weather", name: "Clima", icon: "cloud.fill", color: .sky, badge: nil),
                AppData(id: "Timer", name: "Timer", icon: "timer", color: .orange, badge: state.isTimerRunning ? "!" : nil),
                AppData(id: "Settings", name: "Config", icon: "gearshape.fill", color: .gray, badge: nil)
            ]
        default: return []
        }
    }

    var expandedMusicContent: some View {
        VStack(spacing: 18) {
            HStack(spacing: 15) {
                Button(action: { state.showDashboard() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 22))
                        .opacity(0.3)
                }
                .buttonStyle(.plain)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [state.accentColor.opacity(0.4), state.accentColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    
                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let icon = getAppIcon(for: state.currentPlayer) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.songTitle)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text(state.artistName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .opacity(0.5)
                }
                
                Spacer()
                
                Image(systemName: "waveform")
                    .foregroundColor(.orange)
                    .font(.system(size: 18, weight: .bold))
            }
            
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 5)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(geo.size.width, (geo.size.width * (state.trackPosition / max(1, state.trackDuration))))), height: 5)
                    }
                }
                .frame(height: 5)
                
                HStack {
                    Text(formatTime(state.trackPosition))
                    Spacer()
                    Text("-" + formatTime(max(0, state.trackDuration - state.trackPosition)))
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .opacity(0.4)
            }
            .padding(.top, 5)
            
            if state.isPlaying {
                HStack(spacing: 3) {
                    ForEach(0..<12) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.orange)
                            .frame(width: 3, height: CGFloat.random(in: 4...20))
                    }
                }
                .frame(height: 25)
            }
            
            HStack {
                Button(action: { state.adjustVolume(by: -10) }) {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 12))
                        .opacity(0.4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 35) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.playPause() }) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: { state.openAirPlay() }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 12))
                        .opacity(0.4)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.adjustVolume(by: 10) }) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12))
                        .opacity(0.4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 5)
        }
        .padding(22)
    }

    var dashboardStatusBar: some View {
        HStack {
            statusBarBattery
            Spacer()
            statusBarCenterInfo
            Spacer()
            statusBarConnectivity
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    var statusBarBattery: some View {
        HStack(spacing: 6) {
            Image(systemName: state.isCharging ? "battery.100.bolt" : "battery.75")
                .foregroundColor(state.isCharging ? .green : .white)
            Text("\(state.batteryLevel)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    var statusBarCenterInfo: some View {
        VStack(spacing: 2) {
            if let name = state.headphoneName, let battery = state.headphoneBattery {
                HStack(spacing: 4) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 10))
                    Text("\(name) \(battery)%")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.blue.opacity(0.8))
            }
            
            if state.showClock {
                Text(Date(), style: .time)
                    .font(.system(size: 15, weight: .black, design: .rounded))
            }
        }
    }

    var statusBarConnectivity: some View {
        HStack(spacing: 8) {
            Text(state.wifiSSID)
                .font(.system(size: 10, weight: .bold))
                .opacity(0.6)
                .lineLimit(1)
                .frame(maxWidth: 70)
            
            wifiSignalIndicator
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    var wifiSignalIndicator: some View {
        HStack(alignment: .bottom, spacing: 2) {
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.9)).frame(width: 2.5, height: 2.5)
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.9)).frame(width: 2.5, height: 5.0)
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.9)).frame(width: 2.5, height: 7.5)
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.3)).frame(width: 2.5, height: 10.0)
        }
    }

    var dashboardCategorySelector: some View {
        HStack(spacing: 20) {
            ForEach(state.categories, id: \.self) { cat in
                Button(action: { 
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                        state.activeCategory = cat 
                    }
                }) {
                    VStack(spacing: 6) {
                        Text(cat.uppercased())
                            .font(.system(size: 11, weight: state.activeCategory == cat ? .black : .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(state.activeCategory == cat ? .white : .white.opacity(0.3))
                        
                        // Underline indicator
                        if state.activeCategory == cat {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(state.accentColor)
                                .frame(width: 20, height: 3)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(width: 20, height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 15)
    }
    
    func getAppIcon(for appName: String) -> NSImage? {
        let path = "/Applications/\(appName).app"
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
    
    var batteryContent: some View {
        HStack(spacing: 10) {
            Image(systemName: state.isCharging ? "battery.100.bolt" : "battery.75")
                .foregroundColor(state.isCharging ? .green : .white)
                .font(.system(size: 16, weight: .bold))
            Text("\(state.batteryLevel)%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
    }
    
    var volumeContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12))
            
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: proxy.size.width * state.volume)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 12)
    }
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Widgets
    
    var timerWidget: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TEMPORIZADOR")
                        .font(.system(size: 9, weight: .black))
                        .opacity(0.4)
                    Text(formatTime(state.timerRemaining))
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                }
                
                Spacer()
                
                if state.isTimerRunning {
                    Button(action: { state.stopTimer() }) {
                        Image(systemName: "pause.fill")
                            .frame(width: 40, height: 40)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Circle())
                    }
                } else {
                    Button(action: { state.startTimer(minutes: 0) }) {
                        Image(systemName: "play.fill")
                            .frame(width: 40, height: 40)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                }
            }
            
            if !state.isTimerRunning {
                HStack {
                    Image(systemName: "clock")
                        .opacity(0.4)
                    TextField("Minutos", value: $state.customTimerMinutes, formatter: NumberFormatter())
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 50)
                    
                    Slider(value: $state.customTimerMinutes, in: 1...60, step: 1)
                        .accentColor(.orange)
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(22)
    }
    
    var notesWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NOTAS RÁPIDAS")
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.4)
                Spacer()
                Button(action: { state.addNote() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 8) {
                if state.notes.isEmpty && state.isSyncingNotes {
                    ProgressView().scaleEffect(0.6)
                } else {
                    ForEach(state.notes.prefix(2).indices, id: \.self) { i in
                        Text(state.notes[safe: i]?.content ?? "...")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .lineLimit(1)
                    }
                    
                    if state.notes.count > 2 {
                        Text("+ \(state.notes.count - 2) más...")
                            .font(.system(size: 10))
                            .opacity(0.4)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(22)
    }
    
    var settingsWidget: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("CONFIGURACIÓN DE LA ISLA")
                .font(.system(size: 9, weight: .black))
                .opacity(0.4)
            
            VStack(spacing: 12) {
                // Color de la Isla
                HStack {
                    Label("Color Fondo", systemImage: "paintpalette.fill")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach([Color.black, Color(hex: "1a1a1a"), Color(hex: "001a33"), Color(hex: "1a0033")], id: \.self) { color in
                            Button(action: { state.islandColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(state.islandColor == color ? Color.white : Color.white.opacity(0.2), lineWidth: state.islandColor == color ? 2 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Color Acento
                HStack {
                    Label("Color Acento", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach([Color.orange, Color.green, Color.blue, Color.purple], id: \.self) { color in
                            Button(action: { state.accentColor = color }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(state.accentColor == color ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                Toggle(isOn: Binding(
                    get: { state.showClock },
                    set: { state.showClock = $0 }
                )) {
                    Text("Mostrar Reloj")
                        .font(.system(size: 12, weight: .bold))
                }
                .toggleStyle(SwitchToggleStyle(tint: state.accentColor))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(22)
    }
}

struct AppIcon: View {
    let name: String
    let color: Color
    let appName: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? color.opacity(0.3) : Color(white: 0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
                        )
                    
                    if let icon = getIcon(for: appName) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .padding(9)
                    } else {
                        Image(systemName: name == "Wsp" ? "message.fill" : (name == "Slack" ? "bubbles.and.sparkles.fill" : "app.dashed"))
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    }
                    
                    // Badge indicator
                    if let b = badge, !b.isEmpty {
                        Text(b)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 5, y: -5)
                    }
                }
                Text(name)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? color : .white)
                    .opacity(isSelected ? 1.0 : 0.7)
            }
        }
        .buttonStyle(.plain)
    }
    
    func getIcon(for appName: String) -> NSImage? {
        let path = "/Applications/\(appName).app"
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}

struct MessageRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 30, height: 30)
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

extension Color {
    static let sky = Color(red: 0.35, green: 0.75, blue: 1.0)
    
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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
