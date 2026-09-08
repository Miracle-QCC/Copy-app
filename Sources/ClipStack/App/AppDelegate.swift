import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ClipboardStore()

    private var quickPanelController: QuickPanelController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = BrandIcon.image {
            NSApp.applicationIconImage = icon
        }

        let panelController = QuickPanelController(store: store)
        quickPanelController = panelController

        let manager = GlobalHotKeyManager {
            panelController.toggle()
        }
        hotKeyManager = manager

        registerGlobalHotKey(showFailureAlert: true)

        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshGlobalHotKey),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshGlobalHotKey),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    private func registerGlobalHotKey(showFailureAlert: Bool) {
        guard let hotKeyManager, !hotKeyManager.registerControlV() else {
            return
        }

        if showFailureAlert {
            let alert = NSAlert()
            alert.messageText = "无法注册 Control + V"
            alert.informativeText = "快捷键可能已被其他应用占用。退出占用该快捷键的应用后，请重新启动 ClipStack。"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func refreshGlobalHotKey(_ notification: Notification) {
        // Re-register after wake or user-session activation. Carbon hot keys can
        // be lost when the window server session is rebuilt. Waiting briefly
        // lets the session finish becoming active before registration.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.registerGlobalHotKey(showFailureAlert: false)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hotKeyManager?.unregister()
    }
}
