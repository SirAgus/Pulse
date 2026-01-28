import SwiftUI
import AppKit

struct IslandView: View {
    @EnvironmentObject var state: IslandState
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Main Island Background with Tap Gesture
            RoundedRectangle(cornerRadius: state.isExpanded ? 35 : (state.mode == .idle ? 4 : 20), style: .continuous)
                .fill(state.backgroundStyle == .solid ? state.islandColor : Color.clear)
                .background(
                    ZStack {
                        if state.backgroundStyle == .liquidGlass {
                            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                                .clipShape(RoundedRectangle(cornerRadius: state.isExpanded ? 35 : 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: state.isExpanded ? 35 : 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        } else if state.backgroundStyle == .liquidGlassDark {
                            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                                .clipShape(RoundedRectangle(cornerRadius: state.isExpanded ? 35 : 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: state.isExpanded ? 35 : 20, style: .continuous)
                                        .stroke(Color.black.opacity(0.4), lineWidth: 0.5)
                                )
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if !state.isExpanded {
                        withAnimation(.spring()) {
                            state.toggleExpand()
                        }
                    }
                }
                .shadow(color: Color.black.opacity(state.backgroundStyle == .solid ? 0 : 0.3), radius: 20, x: 0, y: 10)
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
            case .productivity:
                if state.isExpanded {
                    expandedDashboardContent
                } else {
                    compactProductivityContent
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
        HStack(spacing: 8) {
            if state.isMicMuted {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("Activa")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !state.isExpanded {
                withAnimation(.spring()) {
                    state.toggleExpand()
                }
            }
        }
    }
    
    var compactProductivityContent: some View {
        HStack(spacing: 10) {
            if state.isPomodoroRunning {
                HStack(spacing: 6) {
                    Text("🍅")
                    Text(state.formatPomodoroTime())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                }
            } else if state.isMicMuted {
                HStack(spacing: 6) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text("MUTE")
                        .font(.system(size: 10, weight: .bold))
                }
            } else {
                Text("Productividad")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !state.isExpanded {
                withAnimation(.spring()) {
                    state.toggleExpand()
                }
            }
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
                
                MusicWaveform(isPlaying: state.isPlaying, color: .orange, barCount: 3, maxHeight: 12)
            }
        }
        .padding(.horizontal, 15)
        .contentShape(Rectangle())
        .onTapGesture {
            if !state.isExpanded {
                withAnimation(.spring()) {
                    state.toggleExpand()
                }
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -40 {
                        state.nextTrack()
                    } else if value.translation.width > 40 {
                        state.previousTrack()
                    }
                }
        )
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
        .contentShape(Rectangle())
        .onTapGesture {
            if !state.isExpanded {
                withAnimation(.spring()) {
                    state.toggleExpand()
                }
            }
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
            Text(state.notes.first?.content ?? "Notas")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !state.isExpanded {
                withAnimation(.spring()) {
                    state.toggleExpand()
                }
            }
        }
    }
    
    var expandedNotesContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if state.editingNoteIndex != nil {
                    Button(action: { withAnimation(.spring()) { state.editingNoteIndex = nil } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Mis Notas")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow)
                    }
                } else {
                    Button(action: { state.showDashboard() }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 22))
                            .opacity(0.3)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(state.editingNoteIndex != nil ? "EDITOR DE NOTAS" : "MIS NOTAS")
                    .font(.system(size: 10, weight: .black))
                    .letterSpacing(1)
                    .opacity(0.4)
                
                Spacer()
                
                if state.editingNoteIndex == nil {
                    HStack(spacing: 16) {
                        Button(action: { state.openNotesApp() }) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 20))
                                .opacity(0.3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { state.addNote() }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        if let index = state.editingNoteIndex {
                            state.saveNote(at: index, newContent: state.notes[index].content)
                            withAnimation(.spring()) { state.editingNoteIndex = nil }
                        }
                    }) {
                        Text("LISTO")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(state.accentColor)
                            .foregroundColor(.black)
                            .cornerRadius(10, style: .continuous)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)
            .padding(.bottom, 20)
            
            if let index = state.editingNoteIndex {
                // PREMIUM Full screen editor
                TextEditor(text: Binding(
                    get: { state.notes[safe: index]?.content ?? "" },
                    set: { state.notes[index].content = $0 }
                ))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(25)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 25)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                // List View
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if state.isSyncingNotes && state.notes.isEmpty {
                            VStack(spacing: 15) {
                                ProgressView().scaleEffect(0.8)
                                Text("Conectando con iCloud...").font(.system(size: 12, weight: .bold)).opacity(0.4)
                            }.padding(.top, 60).frame(maxWidth: .infinity)
                        } else {
                            ForEach(state.notes.indices, id: \.self) { index in
                                Button(action: { withAnimation(.spring()) { state.editingNoteIndex = index } }) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(state.notes[index].content)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "icloud.fill").font(.system(size: 9))
                                            Text("SINCRONIZADO").font(.system(size: 8, weight: .black))
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.system(size: 10)).opacity(0.3)
                                        }
                                        .opacity(0.3)
                                    }
                                    .padding(22)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(25, style: .continuous)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        state.deleteNote(at: index)
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
            }
        }
    }
    
    var expandedDashboardContent: some View {
        VStack(spacing: 0) {
            dashboardStatusBar
            dashboardCategorySelector
            
            // Content Area based on Category
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                
                ScrollView(showsIndicators: false) { // This ScrollView now wraps both app grid and contextual widgets
                    VStack(spacing: 30) { // Even more spacing
                        if state.activeCategory == "Dispositivos" {
                            dashboardDevicesGrid
                        } else if state.activeCategory == "Configuración" {
                            settingsWidget
                                .padding(.horizontal, 25)
                        } else {
                            dashboardAppGridContent
                            
                            if state.selectedApp != nil {
                                dashboardContextualWidgets
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .animation(.spring(), value: state.selectedApp)
            .animation(.spring(), value: state.activeCategory)
            
            Spacer(minLength: 20)
            
            dashboardFooter
        }
    }
    var dashboardAppGridContent: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
            ForEach(getAppsForCategory(state.activeCategory), id: \.id) { app in
                AppIcon(
                    name: app.name,
                    iconName: app.icon,
                    color: app.color,
                    appName: app.id,
                    isSelected: state.selectedApp == app.id,
                    badge: app.badge,
                    action: {
                        withAnimation {
                            state.openApp(named: app.id)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
    }

    var dashboardAppGrid: some View {
        ScrollView {
            dashboardAppGridContent
                .padding(.vertical, 20)
        }
    }

    var dashboardDevicesGrid: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Main Computer info
                deviceRow(
                    name: "MacBook Pro",
                    detail: "Sistema macOS",
                    icon: "laptopcomputer",
                    battery: state.batteryLevel,
                    isCharging: state.isCharging
                )
                
                // Bluetooth Header
                HStack {
                    Text("BLUETOOTH")
                        .font(.system(size: 10, weight: .black))
                        .opacity(0.3)
                    Spacer()
                    Circle()
                        .fill(state.headphoneName != nil ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 10)
                .padding(.top, 5)

                // Bluetooth Devices (Real)
                ForEach(state.bluetoothDevices) { device in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 36, height: 36)
                                Image(systemName: device.name.lowercased().contains("audio") || device.name.lowercased().contains("buds") || device.name.lowercased().contains("pods") ? "airpodspro" : "bolt.horizontal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(state.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(device.name)
                                    .font(.system(size: 13, weight: .bold))
                                Text("Conectado")
                                    .font(.system(size: 10))
                                    .opacity(0.4)
                            }
                            
                            Spacer()
                            
                            Button(action: { state.disconnectBluetoothDevice(address: device.id) }) {
                                Text("Desconectar")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        
                        // Volume control if it's the current headset
                        if device.name == state.headphoneName {
                            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 15)
                            
                            HStack(spacing: 10) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 9))
                                    .opacity(0.3)
                                
                                Slider(value: $state.volume, in: 0...1) { _ in
                                    state.refreshVolume()
                                }
                                .accentColor(.blue)
                                .controlSize(.mini)
                                
                                Text("\(Int(state.volume * 100))%")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .frame(width: 25)
                                    .opacity(0.5)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
                
                if state.bluetoothDevices.isEmpty {
                    HStack {
                        Image(systemName: "headphones")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.1))
                        Text("Buscando dispositivos...")
                            .font(.system(size: 12, weight: .bold))
                            .opacity(0.2)
                        Spacer()
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(14)
                }
                
                // WiFi Info (More compact)
                HStack(spacing: 12) {
                    Image(systemName: "wifi")
                        .font(.system(size: 14))
                        .foregroundColor(.blue.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.wifiSSID)
                            .font(.system(size: 13, weight: .bold))
                        Text("Wi-Fi")
                            .font(.system(size: 10))
                            .opacity(0.3)
                    }
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
        }
        .frame(maxHeight: 280)
    }

    func deviceRow(name: String, detail: String, icon: String, battery: Int, isCharging: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(state.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                Text(detail)
                    .font(.system(size: 10))
                    .opacity(0.4)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 9))
                }
                
                Text("\(battery)%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 25, height: 12)
                    Capsule()
                        .fill(battery < 20 ? Color.red : (isCharging ? Color.green : Color.white))
                        .frame(width: CGFloat(battery) * 0.25, height: 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
                    } else if selected == "Meeting" {
                        meetingWidget
                    } else if selected == "Clipboard" {
                        clipboardWidget
                    } else if selected == "Weather" {
                        weatherWidget
                    } else if selected == "Calendar" {
                        calendarWidget
                    } else if selected == "Pomodoro" {
                        pomodoroWidget
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
                AppData(id: "Meeting", name: "Reunión", icon: "video.fill", color: .blue, badge: nil),
                AppData(id: "Clipboard", name: "Papeles", icon: "doc.on.clipboard.fill", color: .orange, badge: state.clipboardHistory.isEmpty ? nil : "\(state.clipboardHistory.count)"),
                AppData(id: "Pomodoro", name: "Pomodoro", icon: "tomato.fill", color: .red, badge: state.isPomodoroRunning ? "ON" : nil),
                AppData(id: "Calendar", name: "Eventos", icon: "calendar", color: .red, badge: nil)
            ]
        case "Recientes":
            return [
                AppData(id: "Spotify", name: "Spotify", icon: "play.fill", color: .green, badge: nil),
                AppData(id: "Notes", name: "Notas", icon: "note.text", color: .yellow, badge: nil),
                AppData(id: "Finder", name: "Finder", icon: "folder.fill", color: .blue, badge: nil)
            ]
        case "Utilidades":
            return [
                AppData(id: "Weather", name: "Clima", icon: "cloud.fill", color: .blue, badge: nil),
                AppData(id: "Timer", name: "Timer", icon: "timer", color: .orange, badge: state.isTimerRunning ? "!" : nil),
                AppData(id: "Settings", name: "Config", icon: "gearshape.fill", color: .gray, badge: nil)
            ]
        default: return []
        }
    }

    var expandedMusicContent: some View {
        VStack(spacing: 22) {
            // Top Section: Info
            HStack(spacing: 16) {
                Button(action: { state.showDashboard() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(state.accentColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: state.accentColor.opacity(0.3), radius: 10, y: 5)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundStyle(state.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.songTitle)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .lineLimit(1)
                    Text(state.artistName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                MusicWaveform(isPlaying: state.isPlaying, color: state.accentColor, barCount: 4, maxHeight: 20)
            }
            .padding(.top, 10)
            
            // Middle Section: Progress
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(colors: [state.accentColor, state.accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, (geo.size.width * (state.trackPosition / max(1, state.trackDuration))))), height: 6)
                            .shadow(color: state.accentColor.opacity(0.3), radius: 4)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text(formatTime(state.trackPosition))
                    Spacer()
                    Text("-" + formatTime(max(0, state.trackDuration - state.trackPosition)))
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            
            // Bottom Section: Controls
            HStack {
                // Volume
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 30, height: 4) // Static representation for now
                        }
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Main Controls
                HStack(spacing: 30) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.playPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 54, height: 54)
                            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // AirPlay / More
                Button(action: { state.openAirPlay() }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 5)
        }
        .padding(25)
        .background {
            if let artwork = state.trackArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 50)
                    .opacity(0.15)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 {
                        state.nextTrack()
                    } else if value.translation.width > 50 {
                        state.previousTrack()
                    }
                }
        )
    }
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
        HStack(spacing: 0) {
            ForEach(state.categories, id: \.self) { cat in
                Button(action: { 
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                        state.activeCategory = cat 
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: categoryIcon(for: cat))
                            .font(.system(size: 16, weight: state.activeCategory == cat ? .bold : .medium))
                            .foregroundColor(state.activeCategory == cat ? state.accentColor : .white.opacity(0.3))
                            .frame(height: 24)
                        
                        // Small dot indicator instead of underline for icons
                        ZStack {
                            if state.activeCategory == cat {
                                Circle()
                                    .fill(state.accentColor)
                                    .matchedGeometryEffect(id: "tab", in: animation)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                            }
                        }
                        .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }

    func categoryIcon(for cat: String) -> String {
        switch cat {
        case "Favoritos": return "star.fill"
        case "Recientes": return "clock.fill"
        case "Dispositivos": return "macbook.and.iphone"
        case "Utilidades": return "square.grid.2x2.fill"
        case "Configuración": return "gearshape.fill"
        default: return "circle"
        }
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
                
                HStack(spacing: 12) {
                    Button(action: { state.openNotesApp() }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.addNote() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(spacing: 8) {
                if state.notes.isEmpty && state.isSyncingNotes {
                    ProgressView().scaleEffect(0.6)
                } else {
                    ForEach(state.notes.prefix(2).indices, id: \.self) { i in
                        Button(action: {
                            state.setMode(.notes)
                            state.isExpanded = true
                            state.editingNoteIndex = i
                        }) {
                            Text(state.notes[safe: i]?.content ?? "...")
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
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
    
    var meetingWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODO REUNIÓN")
                .font(.system(size: 9, weight: .black)).opacity(0.4)
            
            HStack(spacing: 20) {
                Button(action: { state.toggleMic() }) {
                    VStack(spacing: 8) {
                        Image(systemName: state.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(state.isMicMuted ? .red : .green)
                        Text(state.isMicMuted ? "Muteado" : "Activo")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.toggleDND() }) {
                    VStack(spacing: 8) {
                        Image(systemName: state.isDNDActive ? "moon.fill" : "moon.badge.clock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(state.isDNDActive ? .purple : .white.opacity(0.3))
                        Text(state.isDNDActive ? "DND: ON" : "DND: OFF")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var clipboardWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PORTAPAPELES")
                .font(.system(size: 9, weight: .black)).opacity(0.4)
            
            if state.clipboardHistory.isEmpty {
                Text("Copia algo para empezar...")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.2)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.clipboardHistory.prefix(3), id: \.self) { text in
                        Button(action: { state.pasteFromHistory(text) }) {
                            HStack {
                                Text(text)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "doc.on.doc").font(.system(size: 10)).opacity(0.3)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    var weatherWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CLIMA ACTUAL")
                        .font(.system(size: 9, weight: .black)).opacity(0.4)
                    Text(state.weatherCity)
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                if let temp = state.currentTemp {
                    Text("\(Int(temp))°")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(state.accentColor)
                }
            }
            
            HStack {
                Label("\(state.precipitationProb ?? 0)% lluvia", systemImage: "drop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                Spacer()
                Text("Hoy despejado")
                    .font(.system(size: 11))
                    .opacity(0.4)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
    }
    
    var calendarWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRÓXIMO EVENTO")
                .font(.system(size: 9, weight: .black)).opacity(0.4)
            
            if let event = state.nextEvent {
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    
                    HStack {
                        Image(systemName: "clock.fill").font(.system(size: 10))
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12, weight: .bold))
                        
                        if let loc = event.location {
                            Text("•")
                            Image(systemName: "location.fill").font(.system(size: 10))
                            Text(loc).lineLimit(1)
                        }
                    }
                    .font(.system(size: 11))
                    .opacity(0.5)
                    
                    if let url = event.url {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            Text("Unirse a Reunión")
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(state.accentColor)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 5)
                    }
                }
                .padding(15)
                .background(Color.white.opacity(0.05))
                .cornerRadius(18)
            } else {
                Text("No hay eventos próximos")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.3)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    var pomodoroWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POMODORO")
                        .font(.system(size: 9, weight: .black)).opacity(0.4)
                    Text(state.pomodoroMode == .work ? "Enfoque" : "Descanso")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(state.pomodoroMode == .work ? .red : .green)
                }
                Spacer()
                Text(state.formatPomodoroTime())
                    .font(.system(size: 28, weight: .black, design: .monospaced))
            }
            
            HStack(spacing: 12) {
                Button(action: { state.isPomodoroRunning ? state.pausePomodoro() : state.startPomodoro() }) {
                    Image(systemName: state.isPomodoroRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.resetPomodoro() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 44)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
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
                
                // Estilo de Fondo
                HStack {
                    Label("Estilo", systemImage: "square.stack.3d.up.fill")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(BackgroundStyle.allCases, id: \.self) { style in
                            Button(action: { state.backgroundStyle = style }) {
                                Text(style.rawValue)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(state.backgroundStyle == style ? state.accentColor : Color.white.opacity(0.1))
                                    .foregroundColor(state.backgroundStyle == style ? .black : .white)
                                    .cornerRadius(6)
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
    let iconName: String
    let color: Color
    let appName: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: 1.5)
                        )
                    
                    Group {
                        if let nativeIcon = getIcon(for: appName) {
                            Image(nsImage: nativeIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: iconName)
                                .font(.system(size: 24))
                                .foregroundColor(color)
                        }
                    }
                    .frame(width: 60, height: 60, alignment: .center)
                }
                .overlay(alignment: .topTrailing) {
                    if let badge = badge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black, lineWidth: 1))
                            .offset(x: 10, y: -10)
                    }
                }
                
                Text(name)
                    .font(.system(size: 10, weight: isSelected ? .black : .bold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
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

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
// MARK: - Animated Components

struct MusicWaveform: View {
    var isPlaying: Bool
    var color: Color
    var barCount: Int
    var maxHeight: CGFloat
    
    @State private var barHeights: [CGFloat] = []
    let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
    
    init(isPlaying: Bool, color: Color, barCount: Int = 10, maxHeight: CGFloat = 20) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self.maxHeight = maxHeight
        _barHeights = State(initialValue: (0..<barCount).map { _ in CGFloat.random(in: 4...maxHeight) })
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barHeights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: isPlaying ? barHeights[i] : 4)
            }
        }
        .onReceive(timer) { _ in
            if isPlaying {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    for i in 0..<barHeights.count {
                        barHeights[i] = CGFloat.random(in: 4...maxHeight)
                    }
                }
            }
        }
    }
}
