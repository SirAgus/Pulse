import AppKit

struct NotchInfo {
    let hasNotch: Bool
    let notchRect: NSRect?
}

struct NotchDetector {
    static func notchInfo(for screen: NSScreen) -> NotchInfo {
        let topInset = screen.safeAreaInsets.top
        // auxiliaryTopLeftArea and auxiliaryTopRightArea define the areas 
        // to the left and right of the notch.
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return NotchInfo(hasNotch: false, notchRect: nil)
        }

        let notchX = left.maxX
        let notchWidth = right.minX - left.maxX
        let notchHeight = topInset
        let notchY = screen.frame.maxY - notchHeight

        if notchWidth <= 0 || notchHeight <= 0 {
             print("🏝️ False notch detected (width: \(notchWidth), height: \(notchHeight))")
             return NotchInfo(hasNotch: false, notchRect: nil)
        }

        print("🏝️ Physical Notch detected: Width \(notchWidth), Height \(notchHeight) at x:\(notchX)")
        return NotchInfo(
            hasNotch: true,
            notchRect: NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
        )
    }
    
    static func mainScreenNotch() -> NotchInfo {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NotchInfo(hasNotch: false, notchRect: nil)
        }
        return notchInfo(for: screen)
    }
}
