import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem]
    @Published var searchText = ""
    @Published var selectedFilter: SidebarFilter = .all
    @Published var selectedItemID: ClipboardItem.ID?
    @Published private(set) var isMonitoring = true

    private let pasteboard: NSPasteboard
    private let persistence: ClipboardPersisting
    private let maxHistoryCount: Int
    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        pasteboard: NSPasteboard = .general,
        persistence: ClipboardPersisting = ClipboardPersistence(),
        maxHistoryCount: Int = 500,
        startsMonitoring: Bool = true
    ) {
        self.pasteboard = pasteboard
        self.persistence = persistence
        self.maxHistoryCount = maxHistoryCount
        items = persistence.load().sorted { $0.createdAt > $1.createdAt }
        lastChangeCount = pasteboard.changeCount

        if startsMonitoring {
            startMonitoring()
        }
    }

    var filteredItems: [ClipboardItem] {
        items.filter { item in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return selectedFilter.matches(item)
                && (query.isEmpty || item.searchableText.contains(query))
        }
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else {
            return filteredItems.first
        }
        return items.first { $0.id == selectedItemID }
    }

    func startMonitoring() {
        timer?.invalidate()
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.capturePasteboardIfNeeded()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func capturePasteboardIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }
        lastChangeCount = pasteboard.changeCount

        if let image = NSImage(pasteboard: pasteboard),
           let data = image.pngData {
            insert(
                ClipboardItem(
                    type: .image,
                    imageData: data,
                    sourceApp: activeApplicationName()
                )
            )
            return
        }

        guard let value = pasteboard.string(forType: .string),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        insert(
            ClipboardItem(
                type: ClipboardItem.contentType(for: value),
                text: value,
                sourceApp: activeApplicationName()
            )
        )
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        if let image = item.image {
            pasteboard.writeObjects([image])
        } else if let text = item.text {
            pasteboard.setString(text, forType: .string)
        }
        lastChangeCount = pasteboard.changeCount
        moveToFront(item.id)
    }

    func toggleFavorite(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].isFavorite.toggle()
        persist()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if selectedItemID == item.id {
            selectedItemID = filteredItems.first?.id
        }
        persist()
    }

    func clearHistory() {
        items.removeAll { !$0.isFavorite }
        selectedItemID = filteredItems.first?.id
        persist()
    }

    func addSampleItemsIfEmpty() {
        guard items.isEmpty else {
            return
        }
        let samples = [
            ClipboardItem(
                type: .text,
                text: "欢迎使用 ClipStack。你复制的内容会自动出现在这里。",
                sourceApp: "ClipStack",
                createdAt: Date()
            ),
            ClipboardItem(
                type: .link,
                text: "https://developer.apple.com/design/human-interface-guidelines/",
                sourceApp: "Safari",
                createdAt: Date().addingTimeInterval(-360)
            ),
            ClipboardItem(
                type: .code,
                text: """
                func greeting(name: String) -> String {
                    "Hello, \\(name)!"
                }
                """,
                sourceApp: "Xcode",
                createdAt: Date().addingTimeInterval(-720)
            )
        ]
        items = samples
        selectedItemID = samples.first?.id
        persist()
    }

    private func insert(_ newItem: ClipboardItem) {
        if let duplicateIndex = items.firstIndex(where: {
            $0.type == newItem.type
                && $0.text == newItem.text
                && $0.imageData == newItem.imageData
        }) {
            var existing = items.remove(at: duplicateIndex)
            existing.createdAt = Date()
            existing.copyCount += 1
            existing.sourceApp = newItem.sourceApp
            items.insert(existing, at: 0)
            selectedItemID = existing.id
        } else {
            items.insert(newItem, at: 0)
            selectedItemID = newItem.id
        }

        trimHistory()
        persist()
    }

    private func moveToFront(_ itemID: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        var item = items.remove(at: index)
        item.createdAt = Date()
        item.copyCount += 1
        items.insert(item, at: 0)
        selectedItemID = item.id
        persist()
    }

    private func trimHistory() {
        guard items.count > maxHistoryCount else {
            return
        }

        let favorites = items.filter(\.isFavorite)
        let regularSlots = max(0, maxHistoryCount - favorites.count)
        let regular = items.filter { !$0.isFavorite }.prefix(regularSlots)
        items = (favorites + regular).sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        persistence.save(items)
    }

    private func activeApplicationName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case text
    case links
    case images
    case code

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部记录"
        case .favorites: "收藏"
        case .text: "文本"
        case .links: "链接"
        case .images: "图片"
        case .code: "代码"
        }
    }

    var symbol: String {
        switch self {
        case .all: "clock.arrow.circlepath"
        case .favorites: "star"
        case .text: ClipboardContentType.text.symbol
        case .links: ClipboardContentType.link.symbol
        case .images: ClipboardContentType.image.symbol
        case .code: ClipboardContentType.code.symbol
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: true
        case .favorites: item.isFavorite
        case .text: item.type == .text
        case .links: item.type == .link
        case .images: item.type == .image
        case .code: item.type == .code
        }
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
