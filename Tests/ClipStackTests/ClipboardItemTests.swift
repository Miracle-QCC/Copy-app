import Testing
@testable import ClipStack

struct ClipboardItemTests {
    @Test
    func detectsLinks() {
        #expect(ClipboardItem.contentType(for: "https://example.com/article") == .link)
    }

    @Test
    func detectsCode() {
        #expect(
            ClipboardItem.contentType(for: "func greet() {\n    print(\"Hello\")\n}") == .code
        )
    }

    @Test
    func plainSentenceIsText() {
        #expect(ClipboardItem.contentType(for: "今天需要整理产品需求。") == .text)
    }

    @Test
    func titleUsesFirstNonEmptyLine() {
        let item = ClipboardItem(type: .text, text: "\n第一行\n第二行")
        #expect(item.title == "第一行")
    }

    @Test
    func hoveringRowMovesQuickPanelSelection() {
        let first = ClipboardItem(type: .text, text: "第一条")
        let second = ClipboardItem(type: .text, text: "第二条")
        var selection = QuickSelection()

        selection.reset(items: [first, second])
        selection.hover(itemID: second.id, items: [first, second])

        #expect(selection.selectedID == second.id)
    }

    @Test
    func hoverIsNotTreatedAsKeyboardNavigation() {
        let first = ClipboardItem(type: .text, text: "第一条")
        let second = ClipboardItem(type: .text, text: "第二条")
        let items = [first, second]
        var selection = QuickSelection()

        selection.reset(items: items)
        selection.hover(itemID: second.id, items: items)

        // Hovering must not request auto-scroll, otherwise the list moves under
        // the cursor and scrolls on its own as the mouse rests in place.
        #expect(selection.lastChangeSource == .hover)
    }

    @Test
    func keyboardNavigationRequestsAutoScroll() {
        let first = ClipboardItem(type: .text, text: "第一条")
        let second = ClipboardItem(type: .text, text: "第二条")
        let items = [first, second]
        var selection = QuickSelection()

        selection.reset(items: items)
        selection.move(.down, items: items)

        #expect(selection.lastChangeSource == .keyboard)
    }

    @Test
    func keyboardSelectionMovesAndStopsAtListBounds() {
        let first = ClipboardItem(type: .text, text: "第一条")
        let second = ClipboardItem(type: .text, text: "第二条")
        let items = [first, second]
        var selection = QuickSelection()

        selection.reset(items: items)
        selection.move(.down, items: items)
        #expect(selection.selectedID == second.id)

        selection.move(.down, items: items)
        #expect(selection.selectedID == second.id)

        selection.move(.up, items: items)
        #expect(selection.selectedID == first.id)
    }
}
