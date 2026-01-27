import Foundation
import AppKit

class MusicObserver {
    static let shared = MusicObserver()
    
    private var syncTimer: Timer?
    
    func start() {
        checkCurrentStatus()
        
        // Start polling timer for position/duration sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if IslandState.shared.isPlaying {
                self?.updateDurations(for: IslandState.shared.currentPlayer)
            }
        }
        
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
            let nowPlaying = (playbackState == "Playing" || playbackState == "playing")
            IslandState.shared.isPlaying = nowPlaying
            
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
        let posScript = "tell application \"\(appName)\" to get player position"
        let durScript = "tell application \"\(appName)\" to get duration of current track"
        
        let posStr = IslandState.shared.executeAppleScript(posScript)
        let durStr = IslandState.shared.executeAppleScript(durScript)
        
        DispatchQueue.main.async {
            // Position is always in seconds for both apps when using "player position"
            if let pRaw = posStr, let pd = Double(pRaw) {
                IslandState.shared.trackPosition = pd
            }
            
            if let dRaw = durStr, let dd = Double(dRaw) {
                // Spotify results are usually in ms if they are > 500
                // Music results are in seconds
                var finalDur = dd
                if appName == "Spotify" && dd > 1000 {
                    finalDur = dd / 1000.0
                }
                
                if finalDur > 1 {
                    IslandState.shared.trackDuration = finalDur
                }
            }
        }
    }
    
    func checkCurrentStatus() {
        let apps = NSWorkspace.shared.runningApplications
        let isSpotifyRunning = apps.contains { $0.bundleIdentifier == "com.spotify.client" }
        let isMusicRunning = apps.contains { $0.bundleIdentifier == "com.apple.Music" }
        
        if isSpotifyRunning {
            let stateStr = IslandState.shared.executeAppleScript("tell application \"Spotify\" to get player state")
            if stateStr == "playing" {
                updateImmediateState(for: "Spotify")
                return
            }
        }
        
        if isMusicRunning {
            let stateStr = IslandState.shared.executeAppleScript("tell application \"Music\" to get player state")
            if stateStr == "playing" {
                updateImmediateState(for: "Music")
                return
            }
        }
    }
    
    private func updateImmediateState(for appName: String) {
        let track = IslandState.shared.executeAppleScript("tell application \"\(appName)\" to get name of current track") ?? "Unknown"
        let artist = IslandState.shared.executeAppleScript("tell application \"\(appName)\" to get artist of current track") ?? "Unknown"
        
        DispatchQueue.main.async {
            IslandState.shared.songTitle = track
            IslandState.shared.artistName = artist
            IslandState.shared.isPlaying = true
            IslandState.shared.currentPlayer = appName
            IslandState.shared.setMode(.music)
            self.updateDurations(for: appName)
        }
    }
    
    func refresh() {
        // Force refresh if needed
    }
}
