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

        var internalBattery: (capacity: Int, isCharging: Bool)?

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let maximumCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 0
                guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                      maximumCapacity > 0 else {
                    continue
                }

                let capacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
                let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
                internalBattery = (capacity, isCharging)
                break
            }
        }

        DispatchQueue.main.async {
            let state = IslandState.shared
            let wasCharging = state.isCharging
            state.hasInternalBattery = internalBattery != nil

            if let internalBattery {
                state.batteryLevel = internalBattery.capacity
                state.isCharging = internalBattery.isCharging

                if internalBattery.isCharging && !wasCharging {
                    state.setMode(.battery)
                }
            } else {
                state.batteryLevel = 0
                state.isCharging = false

                if state.mode == .battery {
                    state.setMode(.compact, autoCollapse: false)
                }
            }
        }
    }
}
