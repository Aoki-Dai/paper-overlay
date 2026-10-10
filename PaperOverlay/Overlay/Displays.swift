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

    /// 設定に使う識別子。UUID が取れないモニター（一部の仮想ディスプレイなど）でも、
    /// 操作できるように画面番号で代用する（こちらは接続し直すと変わることがある）
    var overlayID: String? {
        stableID ?? displayID.map { "display-\($0)" }
    }

    var displayInfo: DisplayInfo? {
        guard let id = overlayID, let displayID else { return nil }
        return DisplayInfo(id: id, name: localizedName, isBuiltIn: CGDisplayIsBuiltin(displayID) != 0)
    }
}
