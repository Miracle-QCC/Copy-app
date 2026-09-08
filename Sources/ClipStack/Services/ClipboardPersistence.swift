import Foundation

protocol ClipboardPersisting {
    func load() -> [ClipboardItem]
    func save(_ items: [ClipboardItem])
}

struct ClipboardPersistence: ClipboardPersisting {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
        let directory = applicationSupport.appendingPathComponent("ClipStack", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("clipboard-history.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([ClipboardItem].self, from: data)) ?? []
    }

    func save(_ items: [ClipboardItem]) {
        guard let data = try? encoder.encode(items) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
