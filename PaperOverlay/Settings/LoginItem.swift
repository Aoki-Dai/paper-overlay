import Observation
import ServiceManagement

/// ログイン時の自動起動。状態は macOS 側（システム設定の「ログイン項目」）が持つので、
/// UserDefaults には保存せず、毎回 SMAppService に問い合わせる
@MainActor
@Observable
final class LoginItem {
    private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled }
    /// 登録はしたが、ユーザーがシステム設定で許可していない
    var requiresApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// システム設定側で変えられることもあるので、画面を開くたびに読み直す
    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
