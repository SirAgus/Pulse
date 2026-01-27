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
            } else if notification.name.rawValue.contains("spotify") {
                IslandState.shared.currentPlayer = "Spotify"
            }
        }
    }
    
    func refresh() {
        // Force refresh if needed
    }
}
