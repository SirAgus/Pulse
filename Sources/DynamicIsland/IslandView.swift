import SwiftUI
import AppKit

struct IslandView: View {
    @EnvironmentObject var state: IslandState
    @Namespace private var animation
    
    var body: some View {
        ZStack { // Remove fixed alignment, use natural centering
            
            // Main Island Container
            RoundedRectangle(cornerRadius: state.isExpanded ? 35 : (state.mode == .idle ? 4 : 15), style: .continuous)
                .fill(Color.black)
                .frame(
                    width: state.widthForMode(state.mode, isExpanded: state.isExpanded),
                    height: state.heightForMode(state.mode, isExpanded: state.isExpanded)
                )
                .overlay(
                    contentForMode(state.mode)
                        .opacity(state.mode == .idle ? 0 : 1)
                )
                .shadow(color: .clear, radius: 0)
                .onTapGesture {
                    state.toggleExpand()
                }
                .contextMenu {
                    Button("Salir") {
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
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
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundColor(.orange)
                .font(.system(size: 10, weight: .bold))
            Text(state.songTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                )
        }
        .padding(.horizontal, 10)
    }
    
    var expandedDashboardContent: some View {
        VStack(spacing: 20) {
            // App Launcher Section
            VStack(alignment: .leading, spacing: 12) {
                Text("ACCESOS RÁPIDOS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .opacity(0.4)
                    .padding(.leading, 5)
                
                HStack(spacing: 20) {
                    AppIcon(name: "Spotify", color: .green, appName: "Spotify", isSelected: state.selectedApp == "Spotify", badge: nil) {
                        state.openApp(named: "Spotify")
                    }
                    AppIcon(name: "Wsp", color: .green, appName: "WhatsApp", isSelected: state.selectedApp == "Wsp", badge: state.wspBadge) {
                        state.openApp(named: "Wsp")
                    }
                    AppIcon(name: "Slack", color: .purple, appName: "Slack", isSelected: state.selectedApp == "Slack", badge: state.slackBadge) {
                        state.openApp(named: "Slack")
                    }
                    AppIcon(name: "Finder", color: .blue, appName: "Finder", isSelected: state.selectedApp == "Finder", badge: nil) {
                        state.openApp(named: "Finder")
                    }
                }
            }
            
            // Contextual Content Section
            if let selected = state.selectedApp {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selected == "Spotify" ? "REPRODUCIENDO" : "RECIBIDOS")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .opacity(0.4)
                        .padding(.leading, 5)
                    
                    VStack(spacing: 8) {
                        if selected == "Wsp" {
                            if state.lastWhatsAppMessages.isEmpty {
                                Text("No hay mensajes nuevos")
                                    .font(.system(size: 11, design: .rounded))
                                    .opacity(0.4)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(state.lastWhatsAppMessages, id: \.self) { msg in
                                    MessageRow(icon: "message.fill", color: .green, text: msg)
                                }
                            }
                        } else if selected == "Slack" {
                            if state.lastSlackMessages.isEmpty {
                                Text("No hay notificaciones")
                                    .font(.system(size: 11, design: .rounded))
                                    .opacity(0.4)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(state.lastSlackMessages, id: \.self) { msg in
                                    MessageRow(icon: "bubbles.and.sparkles.fill", color: .purple, text: msg)
                                }
                            }
                        } else if selected == "Spotify" {
                            if state.isPlaying {
                                MessageRow(icon: "waveform", color: .green, text: "\(state.songTitle) - \(state.artistName)")
                            } else {
                                MessageRow(icon: "play.circle.fill", color: .green, text: "No se está reproduciendo nada")
                            }
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(25)
        .overlay(alignment: .bottomTrailing) {
            if state.isPlaying {
                Button(action: { state.showMusic() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 8, weight: .bold))
                        Text(state.songTitle)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .padding(15)
            }
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
                
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "FF8A00"), Color(hex: "FF0000")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.songTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(state.artistName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.6)
                }
                
                Spacer()
                
                Image(systemName: "waveform")
                    .foregroundColor(.orange)
                    .font(.system(size: 18, weight: .bold))
            }
            
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 120, height: 5)
                }
                
                HStack {
                    Text("1:20")
                    Spacer()
                    Text("-2:45")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .opacity(0.4)
            }
            
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .opacity(0.4)
                
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
                
                Image(systemName: "airplayaudio")
                    .font(.system(size: 12))
                    .opacity(0.4)
            }
            .padding(.horizontal, 5)
        }
        .padding(22)
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
