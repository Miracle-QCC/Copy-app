import AppKit
import SwiftUI

@MainActor
final class QuickPanelController: NSObject {
    private let store: ClipboardStore
    private let panel: QuickPanel
    private var previousApplication: NSRunningApplication?
    private var globalMouseMonitor: Any?

    init(store: ClipboardStore) {
        self.store = store
        panel = QuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 500),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.contentView = NSHostingView(
            rootView: QuickClipboardView(
                store: store,
                onChoose: { [weak self] item in
                    self?.choose(item)
                },
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        )

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.panel.isVisible,
                      !self.panel.frame.contains(NSEvent.mouseLocation) else {
                    return
                }
                self.hide()
            }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            if let globalMouseMonitor {
                NSEvent.removeMonitor(globalMouseMonitor)
            }
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        store.capturePasteboardIfNeeded()
        previousApplication = NSWorkspace.shared.frontmostApplication

        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        if let visibleFrame = targetScreen?.visibleFrame {
            let panelSize = panel.frame.size
            let desiredX = mouseLocation.x - panelSize.width / 2
            let desiredY = mouseLocation.y - panelSize.height - 24
            let x = min(max(desiredX, visibleFrame.minX + 12), visibleFrame.maxX - panelSize.width - 12)
            let y = min(max(desiredY, visibleFrame.minY + 12), visibleFrame.maxY - panelSize.height - 12)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // A non-activating panel can accept keyboard input without taking the
        // foreground application away from the user. This avoids an activation
        // race where Electron and other apps immediately reclaim focus and make
        // the panel disappear.
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        let shouldRestorePreviousApplication = NSApp.isActive
        panel.orderOut(nil)
        if shouldRestorePreviousApplication,
           let previousApplication,
           !previousApplication.isTerminated,
           previousApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApplication.activate()
        }
    }

    private func choose(_ item: ClipboardItem) {
        store.copy(item)
        hide()
    }
}

private final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct QuickClipboardView: View {
    @ObservedObject var store: ClipboardStore
    let onChoose: (ClipboardItem) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = QuickSelection()
    @FocusState private var isSearchFocused: Bool

    private var visibleItems: [ClipboardItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = store.items.filter {
            normalizedQuery.isEmpty || $0.searchableText.contains(normalizedQuery)
        }
        return Array(matches.prefix(20))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if visibleItems.isEmpty {
                ContentUnavailableView {
                    Label(
                        query.isEmpty ? "剪贴板是空的" : "没有搜索结果",
                        systemImage: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass"
                    )
                } description: {
                    Text(query.isEmpty ? "复制内容后按 Control + V 再试一次" : "尝试其他关键词")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(visibleItems) { item in
                                QuickClipboardRow(
                                    item: item,
                                    isSelected: selection.selectedID == item.id
                                )
                                .id(item.id)
                                .onHover { isHovering in
                                    guard isHovering else {
                                        return
                                    }
                                    selection.hover(itemID: item.id, items: visibleItems)
                                }
                                .onTapGesture {
                                    onChoose(item)
                                }
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: selection.selectedID) {
                        if let selectedItemID = selection.selectedID {
                            withAnimation(.easeOut(duration: 0.12)) {
                                proxy.scrollTo(selectedItemID, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()
            footer
        }
        .frame(width: 430, height: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            query = ""
            selection.reset(items: visibleItems)
            isSearchFocused = true
        }
        .onChange(of: query) {
            selection.reset(items: visibleItems)
        }
        .onSubmit {
            if let item = selectedItem {
                onChoose(item)
            }
        }
        .onMoveCommand(perform: moveSelection)
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                BrandIcon(size: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("剪贴板")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Control + V")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索历史记录", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(14)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Label("↑↓ 选择", systemImage: "arrow.up.arrow.down")
            Label("↩ 复制", systemImage: "return")
            Spacer()
            Text("Esc 关闭")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private var selectedItem: ClipboardItem? {
        visibleItems.first { $0.id == selection.selectedID } ?? visibleItems.first
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            selection.move(.up, items: visibleItems)
        case .down:
            selection.move(.down, items: visibleItems)
        default:
            return
        }
    }
}

private struct QuickClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            Group {
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: item.type.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(tint.opacity(0.12))
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(item.sourceApp ?? item.type.title)
                    Text("·")
                    Text(item.createdAt.relativeClipboardDescription)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.19) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var tint: Color {
        switch item.type {
        case .text: .blue
        case .link: .purple
        case .image: .orange
        case .code: .green
        }
    }
}
