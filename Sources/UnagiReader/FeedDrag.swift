import SwiftUI
import UniformTypeIdentifiers

/// What is dragged when a subscription of the sidebar is picked up: its identifier. It can be dropped on a folder row (move into the
/// folder) or on the header 「購読元」 (unfiled) of this app, and nowhere else (`.ownProcess`).
struct FeedDrag: Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json).visibility(.ownProcess)
    }
}
