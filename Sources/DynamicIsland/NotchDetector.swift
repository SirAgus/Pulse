import AppKit

struct NotchInfo {
    let hasNotch: Bool
    let notchRect: NSRect?
}

struct NotchDetector {
    static func notchInfo(for screen: NSScreen) -> NotchInfo {
        let topInset = screen.safeAreaInsets.top
        
        // On macOS, if there's a notch, the top safe area inset is non-zero
        guard topInset > 0 else {
            return NotchInfo(hasNotch: false, notchRect: nil)
        }

        // auxiliaryTopLeftArea and auxiliaryTopRightArea define the areas 
        // to the left and right of the notch.
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            // Technically has a notch area (inset > 0) but we couldn't determine the exact rect
            return NotchInfo(hasNotch: true, notchRect: nil)
        }

        let notchX = left.maxX
        let notchWidth = right.minX - left.maxX
        let notchHeight = topInset
        let notchY = screen.frame.maxY - notchHeight

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
