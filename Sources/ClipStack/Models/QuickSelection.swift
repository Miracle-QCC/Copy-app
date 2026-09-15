import Foundation

struct QuickSelection {
    private(set) var selectedID: ClipboardItem.ID?
    /// Tracks what drove the most recent selection change so the view can decide
    /// whether it should auto-scroll. Keyboard navigation needs to keep the
    /// selected row on screen, while mouse hover must not move the list (doing so
    /// shifts a new row under the cursor and causes runaway scrolling).
    private(set) var lastChangeSource: ChangeSource = .programmatic

    mutating func reset(items: [ClipboardItem]) {
        selectedID = items.first?.id
        lastChangeSource = .programmatic
    }

    mutating func hover(itemID: ClipboardItem.ID, items: [ClipboardItem]) {
        guard items.contains(where: { $0.id == itemID }) else {
            return
        }
        selectedID = itemID
        lastChangeSource = .hover
    }

    mutating func move(_ direction: QuickSelectionDirection, items: [ClipboardItem]) {
        guard !items.isEmpty else {
            selectedID = nil
            lastChangeSource = .keyboard
            return
        }

        let currentIndex = items.firstIndex { $0.id == selectedID } ?? 0
        switch direction {
        case .up:
            selectedID = items[max(0, currentIndex - 1)].id
        case .down:
            selectedID = items[min(items.count - 1, currentIndex + 1)].id
        }
        lastChangeSource = .keyboard
    }
}

extension QuickSelection {
    enum ChangeSource {
        case programmatic
        case hover
        case keyboard
    }
}

enum QuickSelectionDirection {
    case up
    case down
}
