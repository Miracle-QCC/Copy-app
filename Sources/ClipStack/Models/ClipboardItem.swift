import AppKit
import Foundation

enum ClipboardContentType: String, Codable, CaseIterable, Identifiable {
    case text
    case link
    case image
    case code

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "文本"
        case .link: "链接"
        case .image: "图片"
        case .code: "代码"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ClipboardContentType
    var text: String?
    var imageData: Data?
    var sourceApp: String?
    var createdAt: Date
    var isFavorite: Bool
    var copyCount: Int

    init(
        id: UUID = UUID(),
        type: ClipboardContentType,
        text: String? = nil,
        imageData: Data? = nil,
        sourceApp: String? = nil,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        copyCount: Int = 1
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.imageData = imageData
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.copyCount = copyCount
    }

    var title: String {
        if type == .image {
            return "图片"
        }

        let firstLine = text?
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return firstLine?.isEmpty == false ? firstLine! : "空白文本"
    }

    var searchableText: String {
        [title, text, sourceApp]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    var image: NSImage? {
        imageData.flatMap(NSImage.init(data:))
    }

    var byteCount: Int {
        imageData?.count ?? text?.utf8.count ?? 0
    }
}

extension ClipboardItem {
    static func contentType(for text: String) -> ClipboardContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "mailto"].contains(scheme) {
            return .link
        }

        let codeSignals = [
            "func ", "let ", "const ", "var ", "class ", "struct ", "import ",
            "SELECT ", "INSERT ", "UPDATE ", "DELETE ", "</", "=>", "{\n", ";\n"
        ]
        let signalCount = codeSignals.reduce(into: 0) { count, signal in
            if trimmed.localizedCaseInsensitiveContains(signal) {
                count += 1
            }
        }
        if signalCount >= 1 && (trimmed.contains("\n") || trimmed.count > 80) {
            return .code
        }

        return .text
    }
}
