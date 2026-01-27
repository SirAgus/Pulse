import Foundation
import AppKit
import CoreAudio

class VolumeObserver {
    static let shared = VolumeObserver()
    
    private var deviceID: AudioDeviceID = 0
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    func start() {
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            self.updateVolume()
        }
        
        AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddress, nil, block)
    }
    
    private func updateVolume() {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &volume)
        
        DispatchQueue.main.async {
            IslandState.shared.volume = Double(volume)
            // Show volume island briefly
            if IslandState.shared.mode != .music || !IslandState.shared.isExpanded {
                IslandState.shared.setMode(.volume)
            }
        }
    }
}
