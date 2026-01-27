import Foundation
import IOKit.ps

class BatteryObserver {
    static let shared = BatteryObserver()
    
    private var timer: Timer?
    
    func start() {
        updateBatteryStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.updateBatteryStatus()
        }
    }
    
    func updateBatteryStatus() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
                let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
                
                DispatchQueue.main.async {
                    IslandState.shared.batteryLevel = capacity
                    IslandState.shared.isCharging = isCharging
                    
                    // Show battery island briefly if it starts charging or level is low
                    if isCharging {
                        IslandState.shared.setMode(.battery)
                    }
                }
            }
        }
    }
}
