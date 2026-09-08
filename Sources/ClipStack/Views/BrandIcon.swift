import AppKit
import SwiftUI

struct BrandIcon: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = Self.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc.on.clipboard.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: size, height: size)
    }

    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}
