import AppKit
import SwiftUI

@main
struct ClipStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("ClipStack", id: "main") {
            ContentView(store: appDelegate.store)
                .frame(minWidth: 940, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("复制所选记录") {
                    if let item = appDelegate.store.selectedItem {
                        appDelegate.store.copy(item)
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(appDelegate.store.selectedItem == nil)

                Button("收藏所选记录") {
                    if let item = appDelegate.store.selectedItem {
                        appDelegate.store.toggleFavorite(item)
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(appDelegate.store.selectedItem == nil)
            }
        }

        MenuBarExtra("ClipStack", systemImage: "doc.on.clipboard.fill") {
            MenuBarContent(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContent: View {
    @ObservedObject var store: ClipboardStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipStack")
                        .font(.headline)
                    Text(store.isMonitoring ? "正在记录剪贴板" : "记录已暂停")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(store.isMonitoring ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }

            Divider()

            if store.items.isEmpty {
                Text("复制一段文字或图片后会显示在这里")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.items.prefix(5)) { item in
                    Button {
                        store.copy(item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.type.symbol)
                                .frame(width: 18)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .lineLimit(1)
                                Text(item.createdAt.relativeClipboardDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button("打开 ClipStack") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button(store.isMonitoring ? "暂停" : "继续") {
                    if store.isMonitoring {
                        store.stopMonitoring()
                    } else {
                        store.startMonitoring()
                    }
                }
                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
