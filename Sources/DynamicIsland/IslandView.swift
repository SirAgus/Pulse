import SwiftUI
import AppKit
import AVFoundation

/*
 THESIS: Pulse is one continuous instrument attached to the notch, not a grid of floating widgets.
 OWN-WORLD: Matte carbon, mineral-white type, hairline rails, and one spectral signal color.
 STORY: Read the active state, take one clear action, then return to the primary Mac task.
 FIRST VIEWPORT: Status and mode rail above one dominant readout; secondary telemetry follows in aligned bands.
 FORM: Telemetry Ribbon, grounded direction 6, horizontal-spine staging, seed ddbb8a66.
*/
struct IslandView: View {
    @EnvironmentObject var state: IslandState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var animation
    @FocusState private var isSearchFocused: Bool

    private var pulseCarbon: Color {
        Color(red: 0.055, green: 0.063, blue: 0.071)
    }

    private var pulseRaised: Color {
        Color(red: 0.090, green: 0.106, blue: 0.118)
    }

    private var pulseSignal: Color {
        state.accentColor == .white
            ? Color(red: 0.33, green: 0.90, blue: 0.78)
            : state.accentColor
    }

    private var pulseBaseColor: Color {
        guard state.mode != .idle else { return .clear }
        if state.backgroundStyle == .solid {
            return state.islandColor
        }
        return pulseCarbon.opacity(state.backgroundStyle == .liquidGlass ? 0.96 : 0.99)
    }
    
    // Timer icon loaded from Resources
    private var timerIcon: NSImage? {
        // First try Bundle (for installed app)
        if let path = Bundle.main.path(forResource: "timer_icon", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        // Fallback for development (swift run)
        let devPath = "/Users/agus/Documents/Pulse/Resources/timer_icon.png"
        return NSImage(contentsOfFile: devPath)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(pulseBaseColor)
                .overlay(alignment: .top) {
                    if state.mode != .idle {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                }
                .onTapGesture {
                    if !state.isExpanded {
                        state.toggleExpand()
                    }
                }
                .allowsHitTesting(!state.isExpanded)
                .clipShape(islandMask)

            
            // Content Layer
            Group {
                contentForMode(state.mode)
            }
            .clipShape(islandMask)

            
            // Alarms & Alerts Overlays
            if state.isAlarmRinging {
                if state.isExpanded {
                    ringingAlarmOverlay
                } else {
                    compactRingingAlarmOverlay
                }
            } else if state.isPomodoroRinging {
                if state.isExpanded {
                    ringingPomodoroOverlay
                } else {
                    compactRingingPomodoroOverlay
                }
            }

            // Spotify Install Prompt
            if state.showSpotifyInstallPrompt {
                spotifyInstallOverlay
            }
        }
        .padding(.top, 0)
        .background(Color.clear)
        .frame(width: state.widthForMode(state.mode, isExpanded: state.isExpanded),
               height: state.heightForMode(state.mode, isExpanded: state.isExpanded))
        .clipShape(islandMask)
        .onHover { hovering in
            state.isHovering = hovering
        }
        .animation(reduceMotion ? nil : .interpolatingSpring(stiffness: 300, damping: 25), value: state.mode)
        .animation(reduceMotion ? nil : .interpolatingSpring(stiffness: 300, damping: 25), value: state.isExpanded)
        .animation(reduceMotion ? nil : .spring(), value: state.selectedApp)
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
        HStack {
            // Left: Status dot
            HStack(spacing: 6) {
                Circle()
                    .fill(state.accentColor.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
            .frame(width: 30, alignment: .leading)
            .padding(.leading, 15)
            
            Spacer()
            
            // Center: Date & Time
            VStack(spacing: -3) {
                Text(formattedTime)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .fixedSize()
                
                Text(formattedShortDate)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize()
            }
            
            Spacer()
            
            // Right: Battery info
            HStack(spacing: 8) {
                if state.hasInternalBattery {
                    Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(state.batteryLevel < 20 ? .red : .green)
                }
            }
            .frame(width: 30, alignment: .trailing)
            .padding(.trailing, 15)
        }
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    private var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E d 'de' MMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: Date()).uppercased()
    }
    
    var compactProductivityContent: some View {
        HStack {
            HStack(spacing: 8) {
                if state.isPomodoroRunning {
                    if let icon = timerIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Circle()
                        .fill(state.accentColor.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 30, alignment: .leading)
            .padding(.leading, 15)
            
            Spacer()
            
            VStack(spacing: -3) {
                if state.isPomodoroRunning {
                    Text(state.formatPomodoroTime())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                        .fixedSize()
                } else {
                    Text(state.l("Enfoque"))
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if state.hasInternalBattery {
                    Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(state.batteryLevel < 20 ? .red : .green)
                }
            }
            .frame(width: 30, alignment: .trailing)
            .padding(.trailing, 15)
        }
        .frame(height: 32)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
    }
    
    private var islandCornerRadius: CGFloat {
        if state.isExpanded {
            if state.isPomodoroRinging {
                return 16
            }
            return state.mode == .music ? 22 : 24
        } else {
            return 20
        }
    }

    private var islandMask: some Shape {
        // The normal compact island stays attached to the screen edge. Only an
        // expanded surface without a physical notch rounds its upper corners.
        let topRadius = state.isPomodoroRinging
            ? 0
            : (state.isExpanded && !state.hasNotch ? islandCornerRadius : 0)

        return UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: islandCornerRadius,
            bottomTrailingRadius: islandCornerRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        )
    }

    private var focusAlertAlignment: Alignment {
        state.hasNotch ? .bottom : .center
    }

    var compactMusicContent: some View {
        HStack(spacing: 10) {
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
            VStack(alignment: .leading, spacing: 1) {
                Text(state.songTitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                if !state.artistName.isEmpty {
                    Text(state.artistName)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
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
        .padding(.horizontal, 12)
        .frame(height: 32)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
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
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 30, alignment: .leading)
            .padding(.leading, 15)
            
            Spacer()
            
            Text(formatTime(state.timerRemaining))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            
            Spacer()
            
            HStack(spacing: 8) {
                if state.hasInternalBattery {
                    Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(state.batteryLevel < 20 ? .red : .green)
                }
            }
            .frame(width: 30, alignment: .trailing)
            .padding(.trailing, 15)
        }
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
    }
    
    var expandedTimerContent: some View {
        VStack(spacing: 18) {
            HStack {
                Button(action: { state.showDashboard() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text(state.l("Temporizador"))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Circle()
                    .fill(state.isTimerRunning ? pulseSignal : Color.white.opacity(0.24))
                    .frame(width: 5, height: 5)
            }

            Text(formatTime(state.timerRemaining))
                .font(.system(size: 48, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(state.isTimerRunning ? pulseSignal : Color.white.opacity(0.10))
                .frame(height: 3)

            HStack(spacing: 8) {
                if state.isTimerRunning {
                    Button(action: { state.stopTimer() }) {
                        Text(state.l("PAUSAR"))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 112, height: 40)
                            .background(Color.red.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach([5, 10, 25], id: \.self) { minutes in
                        Button(action: { state.startTimer(minutes: minutes) }) {
                            Text("\(minutes) min")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(minutes == 5 ? pulseSignal : pulseRaised)
                                .foregroundColor(minutes == 5 ? .black : .white.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, state.hasNotch ? state.notchHeight + 16 : 20)
        .padding(.bottom, 24)
    }
    
    // MARK: - Native Notes Views
    
    var compactNotesContent: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundColor(pulseSignal)
            }
            .frame(width: 30, alignment: .leading)
            .padding(.leading, 15)
            
            Spacer()
            
            Text(state.notes.first?.content ?? "Notas")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            
            Spacer()
            
            HStack(spacing: 8) {
                if state.hasInternalBattery {
                    Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(state.batteryLevel < 20 ? .red : .green)
                }
            }
            .frame(width: 30, alignment: .trailing)
            .padding(.trailing, 15)
        }
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
    }
    
    var notesHeader: some View {
        HStack {
            Group {
                if state.editingNoteIndex != nil {
                    Button(action: { withAnimation(reduceMotion ? nil : .spring()) { state.editingNoteIndex = nil } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text(state.l("Mis Notas"))
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(pulseSignal)
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
            
            Text(state.editingNoteIndex != nil ? state.l("Editor de notas") : state.l("Mis notas"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))
            
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
                            .foregroundColor(pulseSignal)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: {
                    if let index = state.editingNoteIndex {
                        state.saveNote(at: index, newContent: state.notes[index].content)
                        withAnimation(reduceMotion ? nil : .spring()) { state.editingNoteIndex = nil }
                    }
                }) {
                    Text(state.l("LISTO"))
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(pulseSignal)
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

    @State private var showWifiTooltip: Bool = false
    @State private var showSignalTooltip: Bool = false
    @State private var showSpeedTooltip: Bool = false
    @FocusState private var isNoteFocused: Bool

    var notesEditor: some View {
        Group {
            if let index = state.editingNoteIndex {
                TextField(state.l("Escribe tu nota aquí..."), text: Binding(
                    get: { state.notes[safe: index]?.content ?? "" },
                    set: { state.notes[index].content = $0 }
                ), axis: .vertical)
                .focused($isNoteFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(pulseRaised.opacity(0.72))
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 25)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isNoteFocused = true
                    }
                }
                .onChange(of: state.editingNoteIndex) { oldVal, newVal in
                    if newVal != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isNoteFocused = true
                        }
                    }
                }
            }
        }
    }

    var notesListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if state.isSyncingNotes && state.notes.isEmpty {
                    VStack(spacing: 15) {
                        ProgressView().scaleEffect(0.8)
                        Text(state.l("Conectando con iCloud...")).font(.system(size: 12, weight: .bold)).opacity(0.4)
                    }.padding(.top, 60).frame(maxWidth: .infinity)
                } else {
                    ForEach(state.notes.indices, id: \.self) { index in
                        Button(action: { withAnimation(reduceMotion ? nil : .spring()) { state.editingNoteIndex = index } }) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(state.notes[index].content)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "icloud.fill").font(.system(size: 9))
                                    Text(state.l("Sincronizado")).font(.system(size: 9, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 10)).opacity(0.3)
                                }
                                .opacity(0.3)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .overlay(
                            Button(action: { state.deleteNote(at: index) }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .background(Circle().fill(Color.white).padding(2))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 10)
                            .opacity(state.hoveringNoteIndex == index ? 1 : 0),
                            alignment: .trailing
                        )
                        .onHover { hovering in
                            state.hoveringNoteIndex = hovering ? index : nil
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
        .padding(.top, state.hasNotch ? state.notchHeight : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var expandedDashboardContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("PULSE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.88))

                Text(Date(), style: .time)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.54))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(pulseSignal)
                    Text(state.wifiSSID.isEmpty ? "Wi‑Fi" : state.wifiSSID)
                        .lineLimit(1)
                    if state.hasInternalBattery {
                        Text("·")
                        Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        Text("\(state.batteryLevel)%")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))
            }
            .padding(.horizontal, 20)
            .padding(.top, 13)
            .padding(.bottom, 10)

            if !state.songTitle.isEmpty {
                dashboardNowPlayingBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            
            dashboardTabNavigation
                .padding(.horizontal, 16)

            dashboardSignalRail
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            dashboardTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, state.hasNotch ? state.notchHeight : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var dashboardNowPlayingBar: some View {
        Button(action: { state.showMusic() }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(state.accentColor.opacity(0.14))

                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(state.accentColor)
                    }
                }
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.songTitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text(state.artistName.isEmpty ? state.currentPlayer : state.artistName)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MusicWaveform(
                    isPlaying: state.isPlaying,
                    color: state.accentColor,
                    barCount: 3,
                    maxHeight: 11
                )

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            (state.l("Apps"), "square.grid.2x2", "apps"),
            (state.l("Connect"), "network", "connections"),
            (state.l("Clip"), "clipboard", "clipboard"),
            (state.l("Nook"), "plus.circle", "widgets"),
            (state.l("Media"), "music.note", "media"),
            (state.l("Focus"), "target", "focus"),
            (state.l("Setup"), "gearshape", "settings")
        ]
        
        return HStack(spacing: 2) {
            ForEach(tabs, id: \.2) { tab in
                Button(action: {
                    print("🔘 Tab clicked: \(tab.2)")
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                        state.activeCategory = tab.2
                    }
                }) {
                    VStack(spacing: 5) {
                        Image(systemName: tab.1)
                            .font(.system(size: 13, weight: .semibold))

                        Circle()
                            .fill(state.activeCategory == tab.2 ? pulseSignal : Color.clear)
                            .frame(width: 3, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .foregroundColor(state.activeCategory == tab.2 ? .white : .white.opacity(0.34))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.0)
                .accessibilityLabel(tab.0)
                .accessibilityValue(state.activeCategory == tab.2 ? state.l("Seleccionado") : "")
            }
        }
    }

    var dashboardSignalRail: some View {
        let ids = ["apps", "connections", "clipboard", "widgets", "media", "focus", "settings"]
        let activeIndex = ids.firstIndex(of: state.activeCategory) ?? 0

        return GeometryReader { geometry in
            let segment = geometry.size.width / CGFloat(ids.count)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                Rectangle()
                    .fill(pulseSignal)
                    .frame(width: segment, height: 2)
                    .offset(x: segment * CGFloat(activeIndex))
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: state.activeCategory)
        }
        .frame(height: 2)
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
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: state.activeCategory)
    }
    
    // MARK: - Apps Tab
    var dashboardAppsView: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(state.l("Ahora"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))

                performanceBentoWidget
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(state.l("Acceso rápido"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(getAppsForCategory(state.activeCategory), id: \.id) { app in
                        Button(action: { state.openApp(named: app.id) }) {
                            HStack(spacing: 9) {
                                Image(systemName: app.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(app.color == .white ? pulseSignal : app.color)
                                    .frame(width: 22)

                                Text(app.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.82))
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                if let badge = app.badge, !badge.isEmpty {
                                    Text(badge)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 38)
                            .background(pulseRaised.opacity(0.64))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Header with Widget Adder
            HStack {
                Text(state.l("Sistema"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))
                Spacer()
                Button(action: { withAnimation(reduceMotion ? nil : .spring()) { state.showWidgetPicker.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(state.showWidgetPicker ? state.l("Listo") : state.l("Añadir"))
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pulseSignal)
                    .padding(.horizontal, 10 )
                    .padding(.vertical, 5)
                    .background(pulseSignal.opacity(0.10))
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
                    case "alarm":
                        alarmCarouselWidget
                    case "pomodoro":
                        pomodoroSquareWidget
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.top, 5)
    }
    

    
    
    // Weather removed
    
    var performanceBentoWidget: some View {
        VStack(spacing: 0) {
            telemetryRow(title: state.l("CPU"), value: "\(Int(state.cpuUsage))%", icon: "cpu", progress: state.cpuUsage / 100)
            telemetryRow(title: state.l("Memoria"), value: "\(Int(state.ramUsage))%", icon: "memorychip", progress: state.ramUsage / 100)
            telemetryRow(title: state.l("Temperatura"), value: "\(Int(state.systemTemp))°C", icon: "thermometer", progress: max(0, min(1, (state.systemTemp - 30) / 70)))
            telemetryRow(title: state.l("Disco disponible"), value: state.diskFree, icon: "internaldrive", progress: state.diskUsedPercentage)
        }
    }

    func telemetryRow(title: String, value: String, icon: String, progress: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(pulseSignal)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.70))
                .lineLimit(1)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                    Rectangle()
                        .fill(pulseSignal.opacity(0.88))
                        .frame(width: geometry.size.width * CGFloat(max(0, min(1, progress))))
                }
            }
            .frame(height: 2)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 92, alignment: .trailing)
        }
        .frame(height: 36)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    var alarmCarouselWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "alarm.fill")
                    .foregroundColor(.orange)
                Text(state.l("ALARMAS"))
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.4)
                Spacer()
                Button(action: { withAnimation { state.activeCategory = "widgets" } }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.orange.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if state.alarms.isEmpty {
                wideCircularWidget(
                    icon: "alarm",
                    color: .white.opacity(0.3),
                    title: state.l("ALARMAS"),
                    value: state.l("Sin alarmas"),
                    subValue: state.l("VACÍO"),
                    action: { withAnimation { state.activeCategory = "widgets" } }
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(state.alarms) { alarm in
                            alarmSquareItem(alarm: alarm)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    func alarmSquareItem(alarm: IslandState.Alarm) -> some View {
        ZStack {
            Button(action: { state.toggleAlarm(id: alarm.id) }) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(alarm.isEnabled ? pulseSignal.opacity(0.14) : Color.white.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: alarm.isEnabled ? "alarm.fill" : "alarm")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(alarm.isEnabled ? pulseSignal : .white.opacity(0.4))
                        
                    }
                    
                    VStack(spacing: 2) {
                        Text(alarm.time.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(alarm.isEnabled ? .white : .white.opacity(0.3))
                        Text(alarm.label.isEmpty ? state.l("Alarma") : alarm.label)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(alarm.isEnabled ? pulseSignal.opacity(0.8) : .white.opacity(0.2))
                            .lineLimit(1)
                    }
                }
                .frame(width: 100, height: 110)
                .background(pulseRaised.opacity(alarm.isEnabled ? 0.72 : 0.38))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(alarm.isEnabled ? pulseSignal.opacity(0.24) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Edit & Delete Buttons (Top Right)
            HStack(spacing: 4) {
                Button(action: {
                    newAlarmTime = alarm.time
                    newAlarmLabel = alarm.label
                    selectedRepeatDays = alarm.repeatDays
                    editingAlarmId = alarm.id
                    withAnimation { 
                        isAddingAlarm = true 
                        state.activeCategory = "widgets"
                        state.isExpanded = true
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(pulseSignal.opacity(0.9))
                        .background(Color.black.clipShape(Circle()))
                }
                .buttonStyle(.plain)
                
                Button(action: { state.deleteAlarm(id: alarm.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(0.9))
                        .background(Color.black.clipShape(Circle()))
                }
                .buttonStyle(.plain)
            }
            .offset(x: 32, y: -44)
        }
    }

    var pomodoroSquareWidget: some View {
        wideCircularWidget(
            icon: "timer",
            color: pulseSignal,
            title: state.l("Enfoque"),
            value: state.formatPomodoroTime(),
            subValue: state.isPomodoroRunning ? state.l("En curso") : state.l("Detenido"),
            action: {
                if state.isPomodoroRunning {
                    state.isPomodoroRunning = false
                } else {
                    state.pomodoroRemaining = 25 * 60
                    state.isPomodoroRunning = true
                }
            }
        )
    }

    func wideCircularWidget(icon: String, color: Color, title: String, value: String, subValue: String? = nil, action: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(pulseSignal)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.44))
                    Text(value)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    if let sub = subValue {
                        Text(sub.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(pulseSignal.opacity(0.78))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let onDelete = onDelete {
                    Button(action: { onDelete() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
    
    


    var widgetSelectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                let options = [
                    ("performance", "cpu", pulseSignal),
                    ("alarm", "alarm", pulseSignal),
                    ("pomodoro", "timer", pulseSignal)
                ]
                
                ForEach(options, id: \.0) { opt in
                    Button(action: { 
                        withAnimation(reduceMotion ? nil : .spring()) { state.toggleWidget(opt.0) }
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Image(systemName: opt.1)
                                    .font(.system(size: 16))
                                    .foregroundColor(state.pinnedWidgets.contains(opt.0) ? pulseSignal : .white.opacity(0.44))
                                    .frame(width: 36, height: 30)
                            }
                            Text(opt.0)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.52))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(15)
        }
        .background(pulseRaised.opacity(0.50))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            
            // Standard Progress Bar without GeometryReader recursion
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(0, min(1.0, progress)) * (100 - 24)) // Fixed relative width for performance
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
                    iconColor: pulseSignal,
                    title: state.l("Próximo"),
                    mainText: state.nextEvent?.title ?? state.l("Sin eventos"), 
                    subText: state.nextEvent?.startDate.formatted(date: .omitted, time: .shortened) ?? state.l("Calendario")
                )
            }
            
            // Camera Preview Widget
            if state.hasCamera {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(pulseSignal)
                        Text(state.l("Vista previa de cámara"))
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        
                        // ON/OFF Button
                        Button(action: { withAnimation { state.showCameraPreview.toggle() } }) {
                            Text(state.showCameraPreview ? "ON" : "OFF")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(state.showCameraPreview ? pulseSignal : .white.opacity(0.4))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        Circle()
                            .fill(state.showCameraPreview ? pulseSignal : Color.white.opacity(0.24))
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 4)
                    
                    ZStack {
                        if state.showCameraPreview {
                            CameraPreview()
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "video.slash.fill")
                                            .font(.system(size: 24))
                                            .opacity(0.3)
                                        Text(state.l("Cámara Apagada"))
                                            .font(.system(size: 10, weight: .bold))
                                            .opacity(0.4)
                                    }
                                )
                        }
                    }
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
            }
            

            
            // Alarm Widget
            alarmWidget
        }
    }

    // MARK: - Alarm Widget Computed Property
    @State private var newAlarmTime = Date()
    @State private var newAlarmLabel = ""
    @State private var isAddingAlarm = false
    @State private var selectedRepeatDays: Set<Int> = []
    @State private var editingAlarmId: UUID? = nil
    
    var alarmWidgetHeader: some View {
        HStack {
            Image(systemName: "alarm.fill")
                .font(.system(size: 12))
                .foregroundColor(pulseSignal)
            Text(state.l("Alarmas"))
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            
            Button(action: { withAnimation { isAddingAlarm.toggle() } }) {
                Image(systemName: isAddingAlarm ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
    
    var alarmFormView: some View {
        VStack(spacing: 10) {
            HStack {
                DatePicker("", selection: $newAlarmTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                
                TextField(state.l("Etiqueta"), text: $newAlarmLabel)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(6)
                    .background(pulseRaised)
                    .cornerRadius(8)
            }
            
            alarmRepeatDaysSelector
            alarmSaveButton
        }
        .padding(10)
        .background(pulseRaised.opacity(0.60))
        .cornerRadius(10)
    }
    
    var alarmRepeatDaysSelector: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { day in
                let dayName = Calendar.current.shortWeekdaySymbols[day-1].prefix(1)
                Text(dayName)
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(selectedRepeatDays.contains(day) ? pulseSignal : Color.white.opacity(0.1))
                    .foregroundColor(selectedRepeatDays.contains(day) ? .black : .white)
                    .clipShape(Circle())
                    .onTapGesture {
                        if selectedRepeatDays.contains(day) {
                            selectedRepeatDays.remove(day)
                        } else {
                            selectedRepeatDays.insert(day)
                        }
                    }
            }
        }
    }
    
    var alarmSaveButton: some View {
        Button(action: {
            if let editId = editingAlarmId {
                state.updateAlarm(id: editId, time: newAlarmTime, label: newAlarmLabel.isEmpty ? "Alarma" : newAlarmLabel, repeatDays: selectedRepeatDays)
            } else {
                state.addAlarm(time: newAlarmTime, label: newAlarmLabel.isEmpty ? "Alarma" : newAlarmLabel, repeatDays: selectedRepeatDays)
            }
            
            withAnimation {
                isAddingAlarm = false
                newAlarmLabel = ""
                selectedRepeatDays = []
                editingAlarmId = nil
            }
        }) {
            Text(editingAlarmId != nil ? "Actualizar Alarma" : "Guardar Alarma")
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.orange)
                .foregroundColor(.black)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    func alarmListItem(_ alarm: IslandState.Alarm) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.time.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(alarm.isEnabled ? .white : .white.opacity(0.4))
                
                HStack(spacing: 4) {
                    Text(alarm.label)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if !alarm.repeatDays.isEmpty {
                        let daysText = alarm.repeatDays.sorted().map { Calendar.current.shortWeekdaySymbols[$0-1].prefix(1) }.joined(separator: ",")
                        Text("• \(daysText)")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    newAlarmTime = alarm.time
                    newAlarmLabel = alarm.label
                    selectedRepeatDays = alarm.repeatDays
                    editingAlarmId = alarm.id
                    withAnimation { 
                        isAddingAlarm = true 
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in state.toggleAlarm(id: alarm.id) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                .labelsHidden()
                .scaleEffect(0.7)
                
                Button(action: { state.deleteAlarm(id: alarm.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
    
    var alarmWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            alarmWidgetHeader
            
            if isAddingAlarm {
                alarmFormView
            }
            
            if state.alarms.isEmpty && !isAddingAlarm {
                Text(state.l("No hay alarmas configuradas"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.alarms.filter { alarm in
                        editingAlarmId == nil || alarm.id != editingAlarmId
                    }) { alarm in
                        alarmListItem(alarm)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    var ringingAlarmOverlay: some View {
        VStack(spacing: 20) {
            // Gap for notch
            Spacer().frame(height: state.hasNotch ? state.notchHeight + 20 : 40)
            
            if #available(macOS 15.0, *) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.orange)
                    .symbolEffect(.bounce, options: .repeating)
            } else {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text(state.l("ALARMA"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.orange.opacity(0.8))
                Text(state.activeAlarmLabel)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: { state.stopAlarm() }) {
                Text(state.l("DETENER"))
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .cornerRadius(22)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(islandMask)
    }

    var ringingPomodoroOverlay: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(state.pomodoroMode == .work ? state.l("DESCANSO TERMINADO") : state.l("ENFOQUE TERMINADO"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(1)
                Text(state.pomodoroMode == .work ? state.l("¡A trabajar!") : state.l("¡Buen trabajo!"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 168)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(pulseSignal)

                Spacer()

                Button(action: { state.stopPomodoroAlarm() }) {
                    Text(state.l("LISTO"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 64, height: 32)
                        .background(pulseSignal)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: focusAlertAlignment)
        .background(Color.black)
        .clipShape(islandMask)
        .overlay {
            islandMask
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
                .padding(0.5)
        }
    }

    var compactRingingAlarmOverlay: some View {
        ZStack {
            // Central content - Lowered to be below notch
            HStack(spacing: 8) {
                if #available(macOS 15.0, *) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                        .symbolEffect(.bounce, options: .repeating)
                } else {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                Text(state.activeAlarmLabel.isEmpty ? "ALARMA" : state.activeAlarmLabel)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(height: 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            
            // Left: Stop button - Lowered
            HStack {
                Button(action: { state.stopAlarm() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            
            // Right: Expand hint - Lowered
            HStack {
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(islandMask)
        .contentShape(Rectangle())
        .onTapGesture {
            state.expand()
        }
    }

    var compactRingingPomodoroOverlay: some View {
        ZStack {
            // Central content - Lowered to be below notch
            HStack(spacing: 8) {
                if #available(macOS 15.0, *) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(state.accentColor)
                        .symbolEffect(.bounce, options: .repeating)
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(state.accentColor)
                }
                
                Text(state.pomodoroMode == .work ? state.l("ENFOQUE LISTO") : state.l("DESCANSO LISTO"))
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: focusAlertAlignment)
            
            // Left: Stop button - Lowered
            HStack {
                Button(action: { state.stopPomodoroAlarm() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: focusAlertAlignment)
            
            // Right: Expand hint - Lowered
            HStack {
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: focusAlertAlignment)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .clipShape(islandMask)
        .overlay {
            islandMask
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
                .padding(0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            state.expand()
        }
    }
    
    func widgetCard(icon: String, iconColor: Color, title: String, mainText: String, subText: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(pulseSignal)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.44))
                Text(mainText)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer()

            Text(subText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.52))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
    }
    
    // MARK: - Media Tab
    var dashboardMediaView: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(pulseRaised)

                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(pulseSignal)
                    }
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.songTitle.isEmpty ? state.l("No reproduciendo") : state.songTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)

                    Text(state.artistName.isEmpty ? state.currentPlayer : "\(state.artistName) · \(state.currentPlayer)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer()

                MusicWaveform(isPlaying: state.isPlaying, color: pulseSignal, barCount: 9, maxHeight: 26)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                    Rectangle()
                        .fill(pulseSignal)
                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(state.trackPosition / max(1, state.trackDuration)))))
                }
            }
            .frame(height: 2)

            HStack(spacing: 22) {
                Button(action: { state.previousTrack() }) {
                    Image(systemName: "backward.fill")
                }

                Button(action: { state.musicControl("playpause") }) {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 42, height: 36)
                        .background(pulseSignal)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button(action: { state.nextTrack() }) {
                    Image(systemName: "forward.fill")
                }

                Spacer()

                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.44))

                    Slider(value: Binding(
                        get: { Float(state.volume) },
                        set: { state.setSystemVolume($0) }
                    ), in: 0...1)
                    .tint(pulseSignal)
                    .frame(width: 150)

                    Text("\(Int(state.volume * 100))%")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.64))
                        .frame(width: 34, alignment: .trailing)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.66))
        }
        .padding(.vertical, 8)
    }
    
    
    // MARK: - Focus Tab (Pomodoro)
    var dashboardFocusView: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.pomodoroMode == .work ? state.l("Enfoque") : state.l("Descanso"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(pulseSignal)

                    Text(state.formatPomodoroTime())
                        .font(.system(size: 42, weight: .semibold, design: .monospaced))
                        .tracking(-1.4)
                        .monospacedDigit()
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        if state.isPomodoroRunning {
                            state.pausePomodoro()
                        } else {
                            state.startPomodoro()
                        }
                    }
                }) {
                    Text(state.isPomodoroRunning ? state.l("PAUSAR") : state.l("INICIAR"))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(state.isPomodoroRunning ? .white : .black)
                        .frame(width: 108, height: 40)
                        .background(state.isPomodoroRunning ? Color.red.opacity(0.72) : pulseSignal)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: { state.resetPomodoro() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.62))
                        .frame(width: 40, height: 40)
                        .background(pulseRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geometry in
                let total = state.pomodoroMode == .work ? state.workDuration : state.breakDuration
                let ratio = total > 0 ? 1 - (state.pomodoroRemaining / total) : 0
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                    Rectangle()
                        .fill(pulseSignal)
                        .frame(width: geometry.size.width * CGFloat(max(0, min(1, ratio))))
                }
            }
            .frame(height: 3)

            HStack(spacing: 12) {
                Text(state.l("Sesión"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.44))
                    .frame(width: 54, alignment: .leading)

                TextField(state.l("¿En qué vas a trabajar?"), text: $state.pomodoroLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(pulseRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !state.isPomodoroRunning {
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Button(action: { state.pomodoroMode = .work; state.pomodoroRemaining = state.workDuration }) {
                            Text(state.l("TRABAJO"))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(state.pomodoroMode == .work ? pulseSignal.opacity(0.14) : Color.clear)
                                .foregroundColor(state.pomodoroMode == .work ? pulseSignal : .white.opacity(0.44))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: { state.pomodoroMode = .shortBreak; state.pomodoroRemaining = state.breakDuration }) {
                            Text(state.l("DESCANSO"))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(state.pomodoroMode == .shortBreak ? pulseSignal.opacity(0.14) : Color.clear)
                                .foregroundColor(state.pomodoroMode == .shortBreak ? pulseSignal : .white.opacity(0.44))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        ForEach([15, 25, 45, 60], id: \.self) { mins in
                            Button(action: { state.setPomodoroDuration(mins) }) {
                                Text("\(mins)m")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .frame(width: 42, height: 28)
                                    .background(state.pomodoroRemaining == Double(mins * 60) ? pulseSignal : pulseRaised)
                                    .foregroundColor(state.pomodoroRemaining == Double(mins * 60) ? .black : .white.opacity(0.64))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        Text(state.l("Personalizado"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.44))

                        Slider(value: $state.customTimerMinutes, in: 1...120, step: 1)
                            .tint(pulseSignal)

                        Text("\(Int(state.customTimerMinutes)) min")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 54, alignment: .trailing)

                        Button(action: { state.setPomodoroDuration(Int(state.customTimerMinutes)) }) {
                            Text(state.l("Fijar"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(pulseSignal)
                                .frame(width: 46, height: 28)
                                .background(pulseSignal.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(state.isPomodoroRunning ? pulseSignal : Color.white.opacity(0.24))
                    .frame(width: 5, height: 5)
                Text(state.isPomodoroRunning ? state.l("Bloqueo de distracciones activo") : state.l("Bloqueo de distracciones inactivo"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.44))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Connections Tab
    var dashboardConnectionsView: some View {
        VStack(spacing: 16) {
            wifiCard
                .zIndex(1) // Ensure tooltips render ABOVE the bluetooth list
            bluetoothList
        }
    }
    
    var wifiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            wifiHeader
            wifiStatsRow
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }

    var wifiHeader: some View {
        HStack(alignment: .center) {
            Image(systemName: "wifi")
                .font(.system(size: 18))
                .foregroundColor(pulseSignal)
            Text(state.l(state.wifiSSID))
                .font(.system(size: 16, weight: .semibold))
            
            wifiTooltipIcon
            
            Spacer()
            if state.wifiSpeed > 0 {
                Text("\(state.wifiSpeed) Mbps")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    var wifiTooltipIcon: some View {
        Image(systemName: "questionmark.circle.fill")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.4))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showWifiTooltip = hovering
                }
            }
            .overlay(
                Group {
                    if showWifiTooltip {
                        Text(state.l("WiFi Tooltip"))
                            .font(.system(size: 10, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .frame(width: 220)
                            .fixedSize(horizontal: false, vertical: true)
                            .offset(x: 0, y: 16) // 1px below icon (approx 15px height + 1px)
                            .shadow(radius: 10)
                    }
                },
                alignment: .topLeading // Align to icon's position
            )
            .zIndex(100)
    }

    var wifiStatsRow: some View {
        HStack(spacing: 20) {
            // Signal Stat
            VStack(alignment: .leading) {
                Text(state.l("Señal"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.44))
                Text("\(state.wifiSignal) dBm")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSignalTooltip = hovering
                }
            }
            .overlay(
                Group {
                    if showSignalTooltip {
                        Text(state.l("Signal Tooltip"))
                            .font(.system(size: 10, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .frame(width: 180)
                            .fixedSize(horizontal: false, vertical: true)
                            .offset(x: 0, y: 40)
                            .shadow(radius: 10)
                    }
                },
                alignment: .topLeading
            )
            .zIndex(90)
            
            // Speed Stat
            VStack(alignment: .leading) {
                Text(state.l("Velocidad"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.44))
                Text("\(state.wifiSpeed) Mbps")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSpeedTooltip = hovering
                }
            }
            .overlay(
                Group {
                    if showSpeedTooltip {
                        Text(state.l("Speed Tooltip"))
                            .font(.system(size: 10, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .frame(width: 180)
                            .fixedSize(horizontal: false, vertical: true)
                            .offset(x: 0, y: 40)
                            .shadow(radius: 10)
                    }
                },
                alignment: .topLeading
            )
            .zIndex(90)
            
            Spacer()
            
            // Open WiFi Settings
            Button(action: {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.network")!)
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(pulseSignal)
                    .padding(8)
                    .background(pulseSignal.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    var bluetoothList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.l("Dispositivos Bluetooth"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.76))
                .padding(.horizontal, 4)
            
            if state.bluetoothDevices.isEmpty {
                Text(state.l("No hay dispositivos conectados"))
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.4)
                    .frame(maxWidth: .infinity, alignment: .center) // Force centering
                    .padding(20)
            } else {
                ForEach(state.bluetoothDevices) { device in
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(pulseSignal)
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
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Clipboard Tab
    var dashboardClipboardView: some View {
        VStack(spacing: 16) {
            HStack {
                Text(state.l("Historial del portapapeles"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))
                Spacer()
                Button(action: { state.clipboardHistory.removeAll() }) {
                    Text(state.l("Limpiar"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            if state.clipboardHistory.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 32))
                        .opacity(0.1)
                    Text(state.l("Vacío"))
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
                                    .foregroundColor(pulseSignal)
                                
                                Text(item)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .opacity(0.3)
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Settings Tab
    var dashboardSettingsView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(state.l("Estilo de superficie"))
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Picker("", selection: $state.backgroundStyle) {
                    ForEach(BackgroundStyle.allCases, id: \.self) { style in
                        Text(state.l(style.rawValue)).tag(style)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 108)
            }
            .frame(height: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
            
            HStack {
                Text(state.l("Idioma"))
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Picker("", selection: $state.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(state.l(lang.rawValue)).tag(lang)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 108)
            }
            .frame(height: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
            
            
            if state.backgroundStyle == .solid {
                HStack {
                    Text(state.l("Color de fondo"))
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    ColorPicker("", selection: $state.islandColor)
                        .labelsHidden()
                        .controlSize(.small)
                }
                .frame(height: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            HStack {
                Text(state.l("Color de señal"))
                    .font(.system(size: 11, weight: .medium))

                Spacer()

                ColorPicker("", selection: $state.accentColor)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .frame(height: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
            
            Button(action: { state.collapse() }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.6))
                    Text(state.l("Cerrar Pulse"))
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                }
                .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }
    
    func settingsRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(pulseSignal)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(height: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
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
                    name: state.hasInternalBattery ? "MacBook" : "Mac",
                    detail: state.l("Sistema macOS"),
                    icon: state.hasInternalBattery ? "laptopcomputer" : "macmini",
                    battery: state.hasInternalBattery ? state.batteryLevel : nil,
                    isCharging: state.isCharging
                )
                
                // Bluetooth Header
                HStack {
                    Text(state.l("BLUETOOTH"))
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
                                Text(state.l("Conectado"))
                                    .font(.system(size: 10))
                                    .opacity(0.4)
                            }
                            
                            Spacer()
                            
                            Button(action: { state.disconnectBluetoothDevice(address: device.id) }) {
                                Text(state.l("Desconectar"))
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
                        Text(state.l("Buscando dispositivos..."))
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
                        Text(state.l("Wi-Fi"))
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

    func deviceRow(name: String, detail: String, icon: String, battery: Int?, isCharging: Bool) -> some View {
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
            
            if let battery {
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
            Text("\(state.l("Información de "))\(appName)")
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
                Button(action: { 
                    withAnimation {
                        state.activeCategory = "media"
                        state.mode = .compact
                        state.isExpanded = true
                    }
                }) {
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
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: state.bars[i])
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
        print("📁 IslandView: getAppsForCategory called with '\(cat)'")
        switch cat {
        case "apps", "Apps":
            let apps = [
                AppData(id: "Finder", name: "Finder", icon: "folder.fill", color: .orange, badge: "!"),
                AppData(id: "Notes", name: state.l("Notas"), icon: "note.text", color: .yellow, badge: nil),
                AppData(id: "Chrome", name: "Chrome", icon: "globe", color: .blue, badge: nil)
            ]
            print("   - Returning \(apps.count) apps")
            return apps
        case "widgets", "Utilidades":
            return [
                AppData(id: "Weather", name: state.l("Clima"), icon: "cloud.fill", color: .blue, badge: nil),
                AppData(id: "Timer", name: state.l("Timer"), icon: "timer", color: .orange, badge: state.isTimerRunning ? "!" : nil)
            ]
        default: 
            print("   - No specific apps for category: \(cat)")
            return []
        }
    }

    var expandedMusicContent: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Button(action: { state.showDashboard() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(state.accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    if let artwork = state.trackArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .shadow(color: state.accentColor.opacity(0.25), radius: 7, y: 3)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundStyle(state.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.songTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text(state.artistName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                MusicWaveform(isPlaying: state.isPlaying, color: state.accentColor, barCount: 3, maxHeight: 15)
            }
            
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(colors: [state.accentColor, state.accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, (geo.size.width * (state.trackPosition / max(1, state.trackDuration))))), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(formatTime(state.trackPosition))
                    Spacer()
                    Text("-" + formatTime(max(0, state.trackDuration - state.trackPosition)))
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            
            HStack {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(state.appVolume))), height: 3)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let percent = min(max(0, Float(gesture.location.x / 48)), 1)
                                state.setMusicVolume(percent)
                            }
                    )

                Spacer()

                HStack(spacing: 22) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.playPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 42, height: 42)
                            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: { state.openAirPlay() }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, state.hasNotch ? state.notchHeight + 10 : 12)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if let artwork = state.trackArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 50)
                    .opacity(0.15)
                    .clipShape(islandMask)
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
        Group {
            if state.showClock || state.hasInternalBattery {
                HStack(spacing: 12) {
                    if state.showClock {
                        Text(Date(), style: .time)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    if state.hasInternalBattery {
                        HStack(spacing: 6) {
                            Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                                .foregroundColor(state.isCharging ? .green : .white)
                            Text("\(state.batteryLevel)%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
        }
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
                            .font(.system(size: 16, weight: state.activeCategory == cat ? .bold : .medium))
                            .foregroundColor(state.activeCategory == cat ? state.accentColor : .white.opacity(0.3))
                            .frame(width: 40, height: 20)
                        
                        Text(state.l(cat))
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(state.activeCategory == cat ? state.accentColor : .white.opacity(0.3))
                        
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
        case "Apps": return "square.grid.2x2.fill"
        case "Favoritos": return "star.fill"
        case "Recientes": return "clock.fill"
        case "Dispositivos": return "macbook.and.iphone"
        case "Utilidades": return "briefcase.fill"
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
        Group {
            if state.hasInternalBattery {
                HStack(spacing: 12) {
                    Image(systemName: state.isCharging ? "battery.100.bolt" : batteryIcon)
                        .foregroundColor(state.isCharging ? .green : .white)
                        .font(.system(size: 16, weight: .bold))

                    Text("\(state.batteryLevel)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
    
    var volumeContent: some View {
        HStack(spacing: 10) {
            Image(systemName: state.volume == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill")
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
        .padding(.horizontal, 15)
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
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
                    Text(state.l("TEMPORIZADOR"))
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
                Text(state.l("NOTAS RÁPIDAS"))
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
                        Text("+ \(state.notes.count - 2)\(state.l(" más..."))")
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
    

    var spotifyInstallOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text(state.l("Spotify no instalado"))
                    .font(.system(size: 16, weight: .bold))
                Text(state.l("Parece que no tienes Spotify. ¿Quieres instalarlo?"))
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .opacity(0.6)
            }
            .padding(.horizontal)
            
            VStack(spacing: 10) {
                Button(action: { state.installSpotify(via: "brew") }) {
                    Text(state.l("Instalar por Brew"))
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.installSpotify(via: "web") }) {
                    Text(state.l("Ir a la Web"))
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.showSpotifyInstallPrompt = false }) {
                    Text(state.l("Cancelar"))
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
                .padding(.top, 5)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(40)
    }

    var clipboardWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.l("PORTAPAPELES"))
                .font(.system(size: 9, weight: .black)).opacity(0.4)
            
            if state.clipboardHistory.isEmpty {
                Text(state.l("Copia algo para empezar..."))
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
                    Text(state.l("PRÓXIMO EVENTO"))
                        .font(.system(size: 9, weight: .black)).opacity(0.4)
                    Text(state.l("TU AGENDA"))
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
                                Text(state.l("UNIRSE"))
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
                    Text(state.l("No hay eventos próximos"))
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
                Text(state.l("POMODORO"))
                    .font(.system(size: 9, weight: .black)).opacity(0.4)
                Text(state.l(state.pomodoroMode == .work ? "ENFOQUE" : "DESCANSO"))
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
                    Text(state.isPomodoroRunning ? state.l("PAUSAR") : state.l("INICIAR"))
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
            Label(state.l("Color Fondo"), systemImage: "paintpalette.fill")
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
            Text(state.l("CONFIGURACIÓN DE LA ISLA"))
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
                    Text(state.l("Mostrar Reloj"))
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

// MARK: - App Grid Support

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

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.maxY))
        path.line(to: CGPoint(x: rect.maxX - topRight, y: rect.maxY))
        if topRight > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.maxX - topRight, y: rect.maxY - topRight), radius: topRight, startAngle: 90, endAngle: 0, clockwise: true)
        }
        
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY + bottomRight))
        if bottomRight > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.minY + bottomRight), radius: bottomRight, startAngle: 0, endAngle: 270, clockwise: true)
        }
        
        path.line(to: CGPoint(x: rect.minX + bottomLeft, y: rect.minY))
        if bottomLeft > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.minY + bottomLeft), radius: bottomLeft, startAngle: 270, endAngle: 180, clockwise: true)
        }
        
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY - topLeft))
        if topLeft > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.minX + topLeft, y: rect.maxY - topLeft), radius: topLeft, startAngle: 180, endAngle: 90, clockwise: true)
        }
        
        path.close()
        return Path(path.cgPath)
    }
}

struct UIRectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}
