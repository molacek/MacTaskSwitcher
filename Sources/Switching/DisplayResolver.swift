import AppKit

/// "Active display" = the screen the mouse pointer is currently over.
/// `NSEvent.mouseLocation` and `NSScreen.frame` are both in Cocoa global
/// coordinates (origin bottom-left of the primary screen), so no flipping.
enum DisplayResolver {
    static func activeDisplay() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
    }
}
