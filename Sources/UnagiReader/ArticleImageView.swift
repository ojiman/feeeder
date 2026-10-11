import SwiftUI
import ReaderCore

struct ArticleImageView: View {
    let loader: ReaderImageLoader
    let articleID: UUID
    let url: URL
    let size: CGSize
    @State private var loaded: Loaded?
    private struct Loaded { let key: String; let image: NSImage }
    private var key: String { articleID.uuidString + url.absoluteString }
    var body: some View {
        ZStack {
            Color(nsColor: .quaternaryLabelColor).opacity(0.15)
            if let loaded, loaded.key == key { Image(nsImage: loaded.image).resizable().scaledToFit() }
            else { Image(systemName: "photo").foregroundStyle(.tertiary) }
        }.frame(width: size.width > 0 ? size.width : nil, height: size.height).frame(maxWidth: .infinity).clipped()
        .accessibilityLabel("記事の画像")
        .task(id: key) {
            loaded = nil
            do {
                guard let data = try await loader.image(url: url, at: .now) else { return }
                try Task.checkCancellation()
                if let image = NSImage(data: data) { loaded = Loaded(key: key, image: image) }
            } catch { /* A fixed placeholder keeps reading stable when images fail. */ }
        }
    }
}
