import SwiftUI
import AppKit

struct IslandView: View {
    @EnvironmentObject var state: IslandState
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Main Island Background
            RoundedRectangle(cornerRadius: state.isExpanded ? 35 : (state.mode == .idle ? 4 : 15), style: .continuous)
                .fill(state.islandColor)
            
            // Content Layer (Buttons, text, etc)
            contentForMode(state.mode)
                .opacity(state.mode == .idle ? 0 : 1)
        }
        .contentShape(Rectangle()) // Make the whole frame clickable
        .onTapGesture {
            state.toggleExpand()
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
                    .fill(LinearGradient(colors: [Color.orange.opacity(0.3), Color.red.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 24, height: 24)
                
                if let icon = getAppIcon(for: state.currentPlayer) {
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
                VStack(spacing: 10) {
                    ForEach(0..<state.notes.count, id: \.self) { index in
                        HStack {
                            if state.editingNoteIndex == index {
                                TextField("Contenido...", text: $state.notes[index], onCommit: {
                                    state.editingNoteIndex = nil
                                })
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                            } else {
                                Text(state.notes[index])
                                    .font(.system(size: 13, weight: .medium))
                                    .onTapGesture { state.editingNoteIndex = index }
                                
                                Spacer()
                                
                                Button(action: { state.deleteNote(at: index) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
    }
    
    var expandedDashboardContent: some View {
        VStack(spacing: 0) {
            // Barra de Estado Superior (React Style)
            HStack {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: state.isCharging ? "battery.100.bolt" : "battery.75")
                            .foregroundColor(state.isCharging ? .green : .white)
                        Text("\(state.batteryLevel)%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(state.isCharging ? .green : .white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(state.isCharging ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: .orange.opacity(0.6), radius: 4)
                    
                    // Connected Device (AirPods etc)
                    if let headphone = state.headphoneName, let battery = state.headphoneBattery {
                        HStack(spacing: 6) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("\(battery)%")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(state.wifiSSID)
                        .font(.system(size: 10, weight: .black))
                        .opacity(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: 60)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<4) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(i < 3 ? 0.8 : 0.2)) // Mock signal
                                .frame(width: 2, height: CGFloat((i + 1) * 2))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 25)

            // Selector de Categorías
                HStack(spacing: 0) {
                    ForEach(state.categories, id: \.self) { cat in
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                state.activeCategory = cat 
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(cat.uppercased())
                                    .font(.system(size: 10, weight: state.activeCategory == cat ? .black : .bold, design: .rounded))
                                    .tracking(1.5)
                                    .foregroundColor(state.activeCategory == cat ? .white : .white.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle()) // Better hit area
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: 24, height: 3)
                                        .opacity(state.activeCategory == cat ? 1 : 0)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            .padding(.bottom, 20)
            
            Divider().background(Color.white.opacity(0.1))

            // Parrilla Dinámica de Apps
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(getAppsForCategory(state.activeCategory), id: \.id) { app in
                            Button(action: { 
                                withAnimation {
                                    state.selectedApp = (state.selectedApp == app.id) ? nil : app.id 
                                }
                            }) {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(state.selectedApp == app.id ? Color.white.opacity(0.1) : Color(white: 0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                    .stroke(state.selectedApp == app.id ? app.color : Color.clear, lineWidth: 2)
                                            )
                                        
                                        if let icon = getAppIcon(for: app.name) {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 32, height: 32)
                                        } else {
                                            Image(systemName: app.icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(app.color)
                                        }
                                        
                                        if let badge = app.badge, !badge.isEmpty {
                                            Text(badge)
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundColor(.white)
                                                .frame(width: 20, height: 20)
                                                .background(Color.red)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                                .offset(x: 28, y: -28)
                                        }
                                    }
                                    
                                    Text(app.name)
                                        .font(.system(size: 10, weight: .bold))
                                        .opacity(state.selectedApp == app.id ? 1.0 : 0.4)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Contextual Widgets based on selected app
                    if let selected = state.selectedApp {
                        VStack(spacing: 12) {
                            if selected == "Timer" {
                                timerWidget
                            } else if selected == "Notes" {
                                notesWidget
                            } else if selected == "Settings" {
                                settingsWidget
                            } else {
                                // Default recent info for other apps
                                HStack {
                                    Text("Información de \(selected)")
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                    Image(systemName: "chevron.right").opacity(0.3)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(18)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(25)
            }
            .frame(height: 250)
            
            Spacer()
            
            // Sección Reproduciendo (Footer de la Isla)
            if state.isPlaying || !state.songTitle.isEmpty {
                Button(action: { state.showMusic() }) {
                    HStack(spacing: 15) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(colors: [Color.green.opacity(0.2), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 56, height: 56)
                            
                            if let icon = getAppIcon(for: state.currentPlayer) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundColor(.green)
                                    .font(.system(size: 24))
                            }
                        }
                        
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
                        
                        // Visualizador Pro
                        HStack(spacing: 3) {
                            ForEach(0..<state.bars.count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.green)
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
                    
                    if let icon = getAppIcon(for: state.currentPlayer) {
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
                ForEach(state.notes.prefix(2).indices, id: \.self) { i in
                    Text(state.notes[i])
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
                            Circle()
                                .fill(color)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .onTapGesture { state.islandColor = color }
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
                            Circle()
                                .fill(color)
                                .frame(width: 20, height: 20)
                                .onTapGesture { state.accentColor = color }
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
