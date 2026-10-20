import Cocoa
import ApplicationServices

enum FocusProbe {
    static func textInputFocused() -> (Bool, role: String, bundleID: String) {
        if NSApp.isActive { return (false, "", "") }

        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        var focusedVal: AnyObject?
        let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedVal)
        guard err == .success, let focusedVal = focusedVal else { return (false, "", "") }

        let element = focusedVal as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.1)

        var roleStr = ""
        var roleVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal) == .success,
           let role = roleVal as? String {
            roleStr = role
        }

        var pid: pid_t = 0
        var bundleID = ""
        if AXUIElementGetPid(element, &pid) == .success {
            bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        }
        if bundleID.isEmpty {
            bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        }

        var isTextInput = false
        if roleStr == "AXTextField" || roleStr == "AXTextArea" || roleStr == "AXComboBox" ||
           roleStr == (kAXTextFieldRole as String) ||
           roleStr == (kAXTextAreaRole as String) ||
           roleStr == (kAXComboBoxRole as String) {
            isTextInput = true
        }
        if !isTextInput {
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success,
               settable.boolValue {
                isTextInput = true
            }
        }

        return (isTextInput, roleStr, bundleID)
    }

    static func enableManualAX(pid: pid_t) {
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }
        let app = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
}
