import Foundation

struct QuickSelection {
    private(set) var selectedID: ClipboardItem.ID?

    mutating func reset(items: [ClipboardItem]) {
        selectedID = items.first?.id
    }

    mutating func hover(itemID: ClipboardItem.ID, items: [ClipboardItem]) {
        guard items.contains(where: { $0.id == itemID }) else {
            return
        }
        selectedID = itemID
    }

    mutating func move(_ direction: QuickSelectionDirection, items: [ClipboardItem]) {
        guard !items.isEmpty else {
            selectedID = nil
            return
        }

        let currentIndex = items.firstIndex { $0.id == selectedID } ?? 0
        switch direction {
        case .up:
            selectedID = items[max(0, currentIndex - 1)].id
        case .down:
            selectedID = items[min(items.count - 1, currentIndex + 1)].id
        }
    }
}

enum QuickSelectionDirection {
    case up
    case down
}
