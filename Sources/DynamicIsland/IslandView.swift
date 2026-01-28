import SwiftUI
import AppKit
import AVFoundation

struct IslandView: View {
    @EnvironmentObject var state: IslandState
    @Namespace private var animation
    @FocusState private var isSearchFocused: Bool
    
    // Timer icon loaded from Resources
    private var timerIcon: NSImage? {
        // First try Bundle (for installed app)
        if let path = Bundle.main.path(forResource: "timer_icon", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        // Fallback for development (swift run)
        let devPath = "/Users/agus/Documents/dynamicIsland/Resources/timer_icon.png"
        return NSImage(contentsOfFile: devPath)
    }

    var body: some View {
        ZStack {
            // Main Island Background with Tap Gesture
            RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                .fill((state.backgroundStyle == .solid || !state.isExpanded) && state.mode != .idle ? state.islandColor.opacity(0.98) : Color.black.opacity(0.1))
                .onTapGesture {
                    if !state.isExpanded {
                        state.toggleExpand()
                    }
                }
                .allowsHitTesting(!state.isExpanded)
                .background(
                    ZStack {
                        if state.backgroundStyle == .liquidGlass {
                            VisualEffectView(material: .headerView, blendingMode: .behindWindow)
                                .clipShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        } else if state.backgroundStyle == .liquidGlassDark {
                            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                                .clipShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
            
            // Content Layer
            Group {
                contentForMode(state.mode)
            }
            .clipShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
        }
        .background(Color.clear)
        .frame(width: state.widthForMode(state.mode, isExpanded: state.isExpanded),
               height: state.heightForMode(state.mode, isExpanded: state.isExpanded))
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
                Color.black.opacity(0.01) // Invisible but captures hover
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
            
            // Show Pomodoro timer when focus is active, otherwise show clock
            if state.isPomodoroRunning {
                HStack(spacing: 4) {
                    if let icon = timerIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(state.formatPomodoroTime())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                }
            } else if state.showClock {
                Text(Date(), style: .time)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            } else {
                // Minimalist status dots
                Circle()
                    .fill(state.isMicMuted ? Color.orange : Color.green.opacity(0.8))
                    .frame(width: 4, height: 4)
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
    
    var compactProductivityContent: some View {
        HStack(spacing: 10) {
            if state.isPomodoroRunning {
                HStack(spacing: 6) {
                    if let icon = timerIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(state.formatPomodoroTime())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
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
    
    private var islandCornerRadius: CGFloat {
        if state.isExpanded {
            return state.mode == .music ? 40 : 48
        } else {
            return 20
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
    
    var notesHeader: some View {
        HStack {
            Group {
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
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(state.editingNoteIndex != nil ? "EDITOR DE NOTAS" : "MIS NOTAS")
                .font(.system(size: 10, weight: .black))
                .kerning(1)
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
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 25)
        .padding(.bottom, 20)
    }

    var notesEditor: some View {
        Group {
            if let index = state.editingNoteIndex {
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
            }
        }
    }

    var notesListView: some View {
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
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
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

    var expandedNotesContent: some View {
        VStack(spacing: 0) {
            notesHeader
            
            if state.editingNoteIndex != nil {
                notesEditor
            } else {
                notesListView
            }
        }
    }
    
    var expandedDashboardContent: some View {
        VStack(spacing: 0) {
            // MARK: - Status Bar (Battery, Time, WiFi)
            HStack {
                // Battery indicator
                HStack(spacing: 4) {
                    Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        .font(.system(size: 11))
                        .foregroundColor(state.batteryLevel < 20 ? .red : .green)
                    Text("\(state.batteryLevel)%")
                        .font(.system(size: 10, weight: .black))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
                
                Spacer()
                
                // Time with status dots
                VStack(spacing: 2) {
                    Text(Date(), style: .time)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    HStack(spacing: 4) {
                        Circle().fill(state.isPomodoroRunning ? Color.orange : Color.orange.opacity(0.3))
                            .frame(width: 5, height: 5)
                            .shadow(color: state.isPomodoroRunning ? .orange : .clear, radius: 4)
                        Circle().fill(state.isPlaying ? Color.green : Color.green.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
                
                Spacer()
                
                // WiFi indicator
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text(state.wifiSSID.isEmpty ? "WiFi" : String(state.wifiSSID.prefix(6)))
                        .font(.system(size: 10, weight: .black))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            // MARK: - Tab Navigation (6 tabs)
            dashboardTabNavigation
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // MARK: - Content Area (takes all remaining space)
            dashboardTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            // MARK: - Ambient Light Effects (as overlay, not taking space)
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.06))
                    .frame(width: 150, height: 150)
                    .blur(radius: 60)
                    .offset(x: 120, y: 80)
                Circle()
                    .fill(Color.blue.opacity(0.04))
                    .frame(width: 150, height: 150)
                    .blur(radius: 60)
                    .offset(x: -120, y: -50)
            }
            .allowsHitTesting(false)
        )
    }
    
    var batteryIcon: String {
        switch state.batteryLevel {
        case 0..<10: return "battery.0"
        case 10..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }
    
    var dashboardTabNavigation: some View {
        let tabs = [
            ("Apps", "square.grid.2x2", "apps"),
            ("Connect", "network", "connections"),
            ("Clip", "clipboard", "clipboard"),
            ("Nook", "plus.circle", "widgets"),
            ("Media", "music.note", "media"),
            ("Focus", "target", "focus"),
            ("Setup", "gearshape", "settings")
        ]
        
        return HStack(spacing: 6) {
            ForEach(tabs, id: \.2) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.activeCategory = tab.2
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.1)
                            .font(.system(size: 20, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(state.activeCategory == tab.2 ? state.accentColor : Color.clear)
                    .foregroundColor(state.activeCategory == tab.2 ? (state.accentColor == .white ? .black : .black) : .white.opacity(0.4))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .scaleEffect(state.activeCategory == tab.2 ? 1.02 : 1.0)
                .shadow(color: state.activeCategory == tab.2 ? state.accentColor.opacity(0.3) : .clear, radius: 8)
            }
        }
    }
    
    @ViewBuilder
    var dashboardTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                switch state.activeCategory {
                case "apps":
                    dashboardAppsView
                case "connections":
                    dashboardConnectionsView
                case "clipboard":
                    dashboardClipboardView
                case "widgets":
                    dashboardWidgetsView
                case "media":
                    dashboardMediaView
                case "focus":
                    dashboardFocusView
                case "settings":
                    dashboardSettingsView
                default:
                    dashboardAppsView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.activeCategory)
        .onAppear {
            // Ensure window becomes key when interacting if it wasn't
            if let window = NSApp.windows.first(where: { $0 is IslandWindow }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - Apps Tab
    var dashboardAppsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                // Apps Grid
                VStack(alignment: .leading, spacing: 15) {
                    Text("ACCESO RÁPIDO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(getAppsForCategory("apps"), id: \.id) { app in
                            VStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 52, height: 52)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    
                                    Image(systemName: app.icon)
                                        .font(.system(size: 22))
                                        .foregroundColor(app.color)
                                    
                                    if let badge = app.badge, !badge.isEmpty {
                                        Text(badge)
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundColor(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 20, y: -20)
                                    }
                                }
                                
                                Text(app.name)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .onTapGesture {
                                state.openApp(named: app.id)
                            }
                        }
                    }
                }

                // Header with Widget Adder
                HStack {
                    Text("WIDGETS DEL SISTEMA")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Button(action: { withAnimation(.spring()) { state.showWidgetPicker.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text(state.showWidgetPicker ? "LISTO" : "AÑADIR")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(state.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(state.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                if state.showWidgetPicker {
                    widgetSelectionPicker
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Dynamic Widgets Area
                VStack(spacing: 20) {
                    ForEach(state.pinnedWidgets, id: \.self) { widgetId in
                        switch widgetId {
                        case "photos":
                            photosWidget
                        case "performance":
                            performanceBentoWidget
                        case "camera":
                            cameraSmallWidget
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(.top, 5)
        }
    }
    

    
    var photosWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 140)
                
                VStack(spacing: 15) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    Text("Aquí se mostrarán las fotos cuando terminen de procesarse.")
                        .font(.system(size: 11, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 40)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // Weather removed
    
    var performanceBentoWidget: some View {
        HStack(spacing: 12) {
            systemWidget(title: "CPU", value: "\(Int(state.cpuUsage))%", icon: "cpu", color: .green, progress: state.cpuUsage/100)
            systemWidget(title: "RAM", value: "\(Int(state.ramUsage))%", icon: "memorychip", color: .blue, progress: state.ramUsage/100)
            systemWidget(title: "TEMP", value: "\(Int(state.systemTemp))°C", icon: "thermometer", color: .orange, progress: (state.systemTemp - 30)/70)
            systemWidget(title: "SSD", value: state.diskFree, icon: "internaldrive.fill", color: .purple, progress: state.diskUsedPercentage)
        }
    }
    
    var cameraSmallWidget: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red, radius: 4)
            Text("CÁMARA EN VIVO")
                .font(.system(size: 9, weight: .black))
            Spacer()
            Image(systemName: "video.fill")
                .font(.system(size: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(state.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
    
    var widgetSelectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                let options = [

                    ("performance", "cpu", Color.green),
                    ("photos", "photo", Color.purple),
                    ("camera", "camera.fill", state.accentColor)
                ]
                
                ForEach(options, id: \.0) { opt in
                    Button(action: { 
                        withAnimation(.spring()) { state.toggleWidget(opt.0) }
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(state.pinnedWidgets.contains(opt.0) ? opt.2 : Color.white.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: opt.1)
                                    .font(.system(size: 16))
                                    .foregroundColor(state.pinnedWidgets.contains(opt.0) ? .black : .white)
                            }
                            Text(opt.0.uppercased())
                                .font(.system(size: 7, weight: .black))
                                .opacity(0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(15)
        }
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
    
    func miniWidget(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(value)
                .font(.system(size: 11, weight: .black))
                .lineLimit(1)
        }
        .frame(width: 80, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    func systemWidget(title: String, value: String, icon: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(value)
                .font(.system(size: 14, weight: .black))
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Widgets Tab (Nook)
    var dashboardWidgetsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Weather Widget
                // Calendar Widget  
                widgetCard(
                    icon: "calendar", 
                    iconColor: .pink, 
                    title: "PRÓXIMO", 
                    mainText: state.nextEvent?.title ?? "Sin eventos", 
                    subText: state.nextEvent?.startDate.formatted(date: .omitted, time: .shortened) ?? "Calendario"
                )
            }
            
            // Camera Preview Widget
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundColor(state.accentColor)
                    Text("VISTA PREVIA DE CÁMARA")
                        .font(.system(size: 9, weight: .black))
                    Spacer()
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .shadow(color: .red, radius: 4)
                }
                .padding(.horizontal, 4)
                
                ZStack {
                    CameraPreview()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    VStack {
                        Spacer()
                        HStack {
                            Text("Facetime HD Camera")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }
    
    func widgetCard(icon: String, iconColor: Color, title: String, mainText: String, subText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                Spacer()
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(mainText)
                .font(.system(size: 20, weight: .black))
                .lineLimit(1)
            
            Text(subText)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    // MARK: - Media Tab
    var dashboardMediaView: some View {
        VStack(spacing: 16) {
            // Now Playing Card
            HStack(spacing: 16) {
                // Album Art
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                        .shadow(color: .purple.opacity(0.4), radius: 12)
                    
                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                
                // Song Info + Controls
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.songTitle.isEmpty ? "No reproduciendo" : state.songTitle)
                        .font(.system(size: 16, weight: .black))
                        .lineLimit(1)
                    
                    Text("\(state.artistName) • \(state.currentPlayer)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .lineLimit(1)
                    
                    Spacer().frame(height: 8)
                    
                    // Playback Controls
                    HStack(spacing: 16) {
                        Button(action: { state.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { state.musicControl("playpause") }) {
                            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { state.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Audio Visualizer
                MusicWaveform(isPlaying: state.isPlaying, color: .orange, barCount: 5, maxHeight: 32)
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(18)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
            // Volume & Brightness Sliders
            HStack(spacing: 12) {
                sliderCard(icon: "speaker.wave.2.fill", value: Binding(
                    get: { Float(state.volume) },
                    set: { state.setSystemVolume($0) }
                ), label: "VOL")
                
                sliderCard(icon: "sun.max.fill", value: Binding(
                    get: { state.systemBrightness },
                    set: { state.setSystemBrightness($0) }
                ), label: "BRILLO")
            }
        }
    }
    
    func sliderCard(icon: String, value: Binding<Float>, label: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 9, weight: .black))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: CGFloat(value.wrappedValue) * geo.size.width, height: 6)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let percent = min(max(0, Float(gesture.location.x / geo.size.width)), 1)
                            value.wrappedValue = percent
                        }
                )
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    // MARK: - Shelf Tab
    var dashboardShelfView: some View {
        VStack(spacing: 16) {
            // Drop Zone
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text("SUELTA ARCHIVOS AQUÍ")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Multitarea rápida")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(.white.opacity(0.1))
            )
            .contentShape(Rectangle())
            
            // Recent Files
            if !state.clipboardHistory.isEmpty {
                ForEach(state.clipboardHistory.prefix(3), id: \.self) { item in
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        Text(item.prefix(30))
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
            }
        }
    }
    
    // MARK: - Focus Tab (Pomodoro)
    var dashboardFocusView: some View {
        VStack(spacing: 20) {
            // Circular Timer
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(state.pomodoroRemaining) / CGFloat(state.pomodoroMode == .work ? 25 * 60 : 5 * 60))
                    .stroke(state.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: state.accentColor.opacity(0.5), radius: 8)
                
                VStack(spacing: 2) {
                    Text(state.formatPomodoroTime())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("MINUTOS")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            // Control Buttons
            HStack(spacing: 12) {
                Button(action: { 
                    withAnimation { 
                        if state.isPomodoroRunning {
                            state.pausePomodoro()
                        } else {
                            state.startPomodoro()
                        }
                    }
                }) {
                    Text(state.isPomodoroRunning ? "PAUSAR FOCO" : "INICIAR FOCO")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(state.isPomodoroRunning ? .red : .black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(state.isPomodoroRunning ? Color.red.opacity(0.15) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(state.isPomodoroRunning ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: { state.resetPomodoro() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            // Customizable Time
            if !state.isPomodoroRunning {
                HStack(spacing: 8) {
                    ForEach([15, 25, 45, 60], id: \.self) { mins in
                        Button(action: { state.setPomodoroDuration(mins) }) {
                            Text("\(mins)m")
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(state.pomodoroRemaining == Double(mins * 60) ? state.accentColor : Color.white.opacity(0.1))
                                .foregroundColor(state.pomodoroRemaining == Double(mins * 60) ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                
                // Custom Timer Slider
                VStack(spacing: 8) {
                    HStack {
                        Text("PERSONALIZADO:")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("\(Int(state.customTimerMinutes)) MINUTOS")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 22)
                    
                    HStack(spacing: 12) {
                        Slider(value: $state.customTimerMinutes, in: 1...120, step: 1)
                            .accentColor(state.accentColor)
                        
                        Button(action: { state.setPomodoroDuration(Int(state.customTimerMinutes)) }) {
                            Text("FIJAR")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(state.accentColor.opacity(0.15))
                                .foregroundColor(state.accentColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)
                }
            }
            
            // Focus Status
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 10))
                Text("BLOQUEO DE DISTRACCIONES:")
                    .font(.system(size: 9, weight: .bold))
                Text(state.isPomodoroRunning ? "ACTIVO" : "INACTIVO")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(state.isPomodoroRunning ? .green : .white.opacity(0.4))
            }
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Connections Tab
    var dashboardConnectionsView: some View {
        VStack(spacing: 16) {
            // Wi-Fi Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "wifi")
                        .font(.system(size: 18))
                        .foregroundColor(state.wifiSignal > -60 ? .green : (state.wifiSignal > -80 ? .yellow : .red))
                    Text(state.wifiSSID)
                        .font(.system(size: 16, weight: .black))
                    Spacer()
                    if state.wifiSpeed > 0 {
                        Text("\(state.wifiSpeed) Mbps")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("SEÑAL")
                            .font(.system(size: 8, weight: .black))
                            .opacity(0.4)
                        Text("\(state.wifiSignal) dBm")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("VELOCIDAD")
                            .font(.system(size: 8, weight: .black))
                            .opacity(0.4)
                        Text("\(state.wifiSpeed) Mbps")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Spacer()
                    
                    // Open WiFi Settings
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.network")!)
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            
            // Bluetooth List
            VStack(alignment: .leading, spacing: 12) {
                Text("DISPOSITIVOS BLUETOOTH")
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.4)
                    .padding(.horizontal, 4)
                
                if state.bluetoothDevices.isEmpty {
                    Text("No hay dispositivos conectados")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.4)
                        .padding(20)
                } else {
                    ForEach(state.bluetoothDevices) { device in
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                            Text(device.name)
                                .font(.system(size: 12, weight: .bold))
                            
                            Spacer()
                            
                            if let batt = device.batteryPercentage {
                                HStack(spacing: 4) {
                                    Image(systemName: "battery.100")
                                    Text("\(batt)%")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(batt < 20 ? .red : .green)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
    
    // MARK: - Clipboard Tab
    var dashboardClipboardView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("HISTORIAL DE PORTAPAPELES")
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.4)
                Spacer()
                Button(action: { state.clipboardHistory.removeAll() }) {
                    Text("LIMPIAR")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            if state.clipboardHistory.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 32))
                        .opacity(0.1)
                    Text("Vacío")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.3)
                }
                .frame(height: 150)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.clipboardHistory, id: \.self) { item in
                        Button(action: { state.pasteFromHistory(item) }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundColor(state.accentColor)
                                
                                Text(item)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .opacity(0.3)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Settings Tab
    var dashboardSettingsView: some View {
        VStack(spacing: 12) {
            // Background Style
            HStack {
                Text("Estilo")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Picker("", selection: $state.backgroundStyle) {
                    ForEach(BackgroundStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Solid Background Color Picker (Visible only if style is solid)
            if state.backgroundStyle == .solid {
                VStack(alignment: .leading, spacing: 10) {
                    Text("COLOR DEL FONDO (SOLIDO)")
                        .font(.system(size: 9, weight: .black))
                        .opacity(0.4)
                    
                    HStack {
                        ColorPicker("", selection: $state.islandColor)
                            .labelsHidden()
                        Spacer()
                        Text("Personalizado")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(0.6)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Accent Color
            VStack(alignment: .leading, spacing: 10) {
                Text("COLOR DE ACENTO")
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.4)
                
                HStack {
                    ColorPicker("", selection: $state.accentColor)
                        .labelsHidden()
                    Spacer()
                    Text("Personalizado")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.6)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            

            
            settingsRow(icon: "hand.tap.fill", title: "Gestos", value: "Habilitados", color: .blue)
            
            Button(action: { state.collapse() }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.6))
                    Text("Cerrar Island")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
    
    func settingsRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .bold))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.05), Color.black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [state.accentColor.opacity(0.2), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
            
            if let artwork = state.trackArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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
        case "apps":
            return [
                AppData(id: "Finder", name: "Finder", icon: "folder.fill", color: .orange, badge: "!"),
                AppData(id: "Notes", name: "Notas", icon: "note.text", color: .yellow, badge: nil),
                AppData(id: "Chrome", name: "Chrome", icon: "globe", color: .blue, badge: nil)
            ]
        case "Utilidades":
            return [
                AppData(id: "Weather", name: "Clima", icon: "cloud.fill", color: .blue, badge: nil),
                AppData(id: "Timer", name: "Timer", icon: "timer", color: .orange, badge: state.isTimerRunning ? "!" : nil)
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(state.accentColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            ZStack {
                // Left: Volume
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 60, height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(state.appVolume))), height: 4)
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                                        let percent = min(max(0, Float(gesture.location.x / 60)), 1)
                                        state.setMusicVolume(percent)
                                    }
                            )
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                
                // Center: Main Controls
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
                
                // Right: AirPlay
                HStack {
                    Spacer()
                    Button(action: { state.openAirPlay() }) {
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
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
                    .clipShape(RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous))
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
        HStack(spacing: 12) {
            if state.showClock {
                Text(Date(), style: .time)
                    .font(.system(size: 12, weight: .black, design: .rounded))
            }
            HStack(spacing: 6) {
                Image(systemName: state.isCharging ? "battery.100.bolt" : "battery.75")
                    .foregroundColor(state.isCharging ? .green : .white)
                Text("\(state.batteryLevel)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
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
                            .font(.system(size: 18, weight: state.activeCategory == cat ? .bold : .medium))
                            .foregroundColor(state.activeCategory == cat ? state.accentColor : .white.opacity(0.3))
                            .frame(width: 40, height: 24)
                        
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
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
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
        .padding(.top, 45) // Protection for volume below notch
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
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { state.startTimer(minutes: state.customTimerMinutes) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Color.orange)
                            .foregroundColor(.black)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !state.isTimerRunning {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach([5, 10, 15, 30], id: \.self) { mins in
                            Button(action: { state.customTimerMinutes = Double(mins) }) {
                                Text("\(mins)m")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(state.customTimerMinutes == Double(mins) ? Color.orange.opacity(0.3) : Color.white.opacity(0.05))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .opacity(0.4)
                        Slider(value: $state.customTimerMinutes, in: 1...60, step: 1)
                            .accentColor(.orange)
                        Text("\(Int(state.customTimerMinutes))m")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
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
    
    var meetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MODO REUNIÓN")
                    .font(.system(size: 9, weight: .black)).opacity(0.4)
                Text("CONTROLES DE LLAMADA")
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            Spacer()
            Image(systemName: "video.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
    }

    var meetingControls: some View {
        HStack(spacing: 12) {
            // Mic Button
            Button(action: { state.toggleMic() }) {
                VStack(spacing: 8) {
                    Image(systemName: state.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(state.isMicMuted ? .red : .green)
                    Text(state.isMicMuted ? "Muteado" : "Activo")
                        .font(.system(size: 10, weight: .black))
                        .opacity(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(state.isMicMuted ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(state.isMicMuted ? Color.red.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            // DND Button
            Button(action: { state.toggleDND() }) {
                VStack(spacing: 8) {
                    Image(systemName: state.isDNDActive ? "moon.fill" : "moon")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(state.isDNDActive ? .purple : .white.opacity(0.5))
                    Text(state.isDNDActive ? "No Molestar" : "Libre")
                        .font(.system(size: 10, weight: .black))
                        .opacity(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(state.isDNDActive ? Color.purple.opacity(0.1) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(state.isDNDActive ? Color.purple.opacity(0.2) : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    var meetingQuickLaunch: some View {
        HStack(spacing: 10) {
            Text("LANZAR:")
                .font(.system(size: 8, weight: .bold)).opacity(0.3)
            
            ForEach(["FaceTime", "Zoom", "Slack"], id: \.self) { app in
                Button(action: { state.launchApp(named: app) }) {
                    Text(app)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var meetingWidget: some View {
        VStack(alignment: .leading, spacing: 18) {
            meetingHeader
            meetingControls
            meetingQuickLaunch
        }
        .padding(20)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
    

    
    var calendarWidget: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PRÓXIMO EVENTO")
                        .font(.system(size: 9, weight: .black)).opacity(0.4)
                    Text("TU AGENDA")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            
            if let event = state.nextEvent {
                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 15) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        }
                        
                        if let loc = event.location {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                Text(loc).lineLimit(1)
                            }
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.6)
                    
                    if let url = event.url {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            HStack {
                                Image(systemName: "video.fill")
                                Text("UNIRSE A REUNIÓN")
                            }
                            .font(.system(size: 11, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(state.accentColor)
                            .foregroundColor(.black)
                            .cornerRadius(15)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(15)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
            } else {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .opacity(0.2)
                    Text("No hay eventos próximos")
                        .font(.system(size: 13, weight: .bold))
                        .opacity(0.3)
                    Spacer()
                }
                .padding(20)
                .background(Color.white.opacity(0.03))
                .cornerRadius(20)
            }
        }
    }
    
    var pomodoroHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("POMODORO")
                    .font(.system(size: 9, weight: .black)).opacity(0.4)
                Text(state.pomodoroMode == .work ? "ENFOQUE" : "DESCANSO")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(state.pomodoroMode == .work ? .red : .green)
            }
            Spacer()
            Text(state.formatPomodoroTime())
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(state.pomodoroMode == .work ? .red : .green)
        }
    }

    var pomodoroControls: some View {
        HStack(spacing: 12) {
            Button(action: { 
                if state.isPomodoroRunning { state.pausePomodoro() } 
                else { state.startPomodoro() }
            }) {
                HStack {
                    Image(systemName: state.isPomodoroRunning ? "pause.fill" : "play.fill")
                    Text(state.isPomodoroRunning ? "PAUSAR" : "INICIAR")
                }
                .font(.system(size: 12, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(state.isPomodoroRunning ? Color.white.opacity(0.1) : state.accentColor.opacity(0.8))
                .foregroundColor(state.isPomodoroRunning ? .white : .black)
                .cornerRadius(15)
            }
            .buttonStyle(.plain)
            
            Button(action: { state.resetPomodoro() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 50)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(15)
            }
            .buttonStyle(.plain)
        }
    }

    var pomodoroModeSelector: some View {
        HStack(spacing: 8) {
            ForEach([IslandState.PomodoroMode.work, IslandState.PomodoroMode.shortBreak, IslandState.PomodoroMode.longBreak], id: \.self) { mode in
                Button(action: { 
                    state.pomodoroMode = mode
                    state.resetPomodoro()
                }) {
                    Text(mode == .work ? "Trabajo" : (mode == .shortBreak ? "Corto" : "Largo"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(state.pomodoroMode == mode ? state.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var pomodoroWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            pomodoroHeader
            pomodoroControls
            pomodoroModeSelector
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(22)
    }
    
    var islandColorPicker: some View {
        HStack {
            Label("Color Fondo", systemImage: "paintpalette.fill")
                .font(.system(size: 12, weight: .bold))
            Spacer()
            ColorPicker("", selection: $state.islandColor)
                .labelsHidden()
        }
    }

    var backgroundStylePicker: some View {
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
    }

    var accentColorPicker: some View {
        HStack {
            Label("Color Acento", systemImage: "sparkles")
                .font(.system(size: 12, weight: .bold))
            Spacer()
            ColorPicker("", selection: $state.accentColor)
                .labelsHidden()
        }
    }

    var settingsWidget: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("CONFIGURACIÓN DE LA ISLA")
                .font(.system(size: 9, weight: .black))
                .opacity(0.4)
            
            VStack(spacing: 12) {
                islandColorPicker
                backgroundStylePicker
                accentColorPicker
                
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
            VStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? color : Color.white.opacity(0.15), lineWidth: 1.5)
                        )
                    
                    if let nativeIcon = getIcon(for: appName) {
                        Image(nsImage: nativeIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(color)
                    }
                }
                .frame(width: 60, height: 60)
                .overlay(alignment: .topTrailing) {
                    if let badge = badge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.5), lineWidth: 1))
                            .offset(x: 8, y: -8)
                    }
                }
                
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .black : .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
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

// MARK: - Camera Support
struct CameraPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer = previewLayer
        view.wantsLayer = true
        
        session.startRunning()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

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
