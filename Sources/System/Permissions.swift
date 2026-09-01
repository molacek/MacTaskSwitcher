import ApplicationServices

enum Permissions {
    /// Whether the process is Accessibility-trusted. Pass `true` to also show the
    /// system "grant access" prompt when it is not.
    @discardableResult
    static func ensureAccessibility(promptIfNeeded: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: promptIfNeeded] as CFDictionary)
    }
}
