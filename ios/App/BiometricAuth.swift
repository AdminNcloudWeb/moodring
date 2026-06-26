import Foundation
import LocalAuthentication

/// Thin wrapper over LocalAuthentication for the app-lock feature.
///
/// Uses `.deviceOwnerAuthentication`, which tries Face ID / Touch ID first and
/// automatically falls back to the device passcode — so "passcode, fingerprint,
/// or Face ID" all work without us branching on each.
enum BiometricAuth {
    /// Whether the device can authenticate its owner at all (a biometric is
    /// enrolled, or a passcode is set). If false, app lock can't be offered.
    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// The enrolled biometric kind, if any. Only valid after `canEvaluatePolicy`
    /// has been queried on the context, so we do that first.
    static var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return ctx.biometryType
    }

    /// Label for the Settings toggle, matched to what the device actually has.
    static var toggleLabel: String {
        switch biometryType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        case .opticID: return "Unlock with Optic ID"
        default:       return "Require passcode to unlock"
        }
    }

    /// Label for the button on the lock screen.
    static var unlockActionLabel: String {
        switch biometryType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        case .opticID: return "Unlock with Optic ID"
        default:       return "Unlock"
        }
    }

    /// Prompt the user to authenticate. Returns true on success, false if the
    /// user cancelled/failed or the device can't authenticate.
    static func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
