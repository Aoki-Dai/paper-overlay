import AppKit

/// 接続中のモニター 1 台ぶんの情報
struct DisplayInfo: Identifiable, Equatable, Sendable {
    /// 再起動や接続し直しでも変わらない識別子（ディスプレイの UUID）
    let id: String
    let name: String
    let isBuiltIn: Bool
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// CGDirectDisplayID は接続のたびに変わることがあるので、保存には UUID を使う
    var stableID: String? {
        guard let displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    var displayInfo: DisplayInfo? {
        guard let id = stableID, let displayID else { return nil }
        return DisplayInfo(id: id, name: localizedName, isBuiltIn: CGDisplayIsBuiltin(displayID) != 0)
    }
}
