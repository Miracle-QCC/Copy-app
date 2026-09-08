import Foundation

extension Date {
    var relativeClipboardDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Int {
    var byteCountDescription: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
