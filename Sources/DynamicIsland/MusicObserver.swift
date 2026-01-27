import Foundation
import AppKit

class MusicObserver {
    static let shared = MusicObserver()
    
    func start() {
        // Observe iTunes/Music player state changes
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { notification in
            self.handleMusicChange(notification)
        }
        
        // Also support Spotify
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            self.handleMusicChange(notification)
        }
    }
    
    private func handleMusicChange(_ notification: Notification) {
        let userInfo = notification.userInfo
        let track = userInfo?["Name"] as? String ?? userInfo?["trackName"] as? String ?? "Unknown"
        let artist = userInfo?["Artist"] as? String ?? userInfo?["artistName"] as? String ?? "Unknown"
        let playbackState = userInfo?["Player State"] as? String ?? userInfo?["playState"] as? String ?? ""
        
        DispatchQueue.main.async {
            IslandState.shared.songTitle = track
            IslandState.shared.artistName = artist
            IslandState.shared.isPlaying = (playbackState == "Playing" || playbackState == "playing")
            
            // Detect player
            if notification.name.rawValue.contains("Music") {
                IslandState.shared.currentPlayer = "Music"
                self.updateDurations(for: "Music")
            } else if notification.name.rawValue.contains("spotify") {
                IslandState.shared.currentPlayer = "Spotify"
                self.updateDurations(for: "Spotify")
            }
        }
    }
    
    private func updateDurations(for appName: String) {
        let positionScript = "tell application \"\(appName)\" to get player position"
        let durationScript = "tell application \"\(appName)\" to get duration of current track"
        
        let pos = IslandState.shared.executeAppleScript(positionScript)
        let dur = IslandState.shared.executeAppleScript(durationScript)
        
        DispatchQueue.main.async {
            if let p = pos, let d = dur, let pd = Double(p), let dd = Double(dur == "ms" ? String(Int(d)!/1000) : d) {
                // Spotify duration can be in ms or seconds depending on version/script
                // Typically Spotify AppleScript returns seconds for player position and ms/seconds for duration.
                // We'll handle both.
                let finalDur = dd > 10000 ? dd / 1000 : dd
                IslandState.shared.trackPosition = pd
                IslandState.shared.trackDuration = finalDur
            }
        }
    }
    
    func refresh() {
        // Force refresh if needed
    }
}
