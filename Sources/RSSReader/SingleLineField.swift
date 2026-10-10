import SwiftUI
import ReaderCore

extension Binding where Value == String {
    /// For a one-line field. A line break that arrives by paste or Option-Return becomes a space, or vanishes for a web address.
    func singleLine(address: Bool = false) -> Binding<String> {
        Binding(get: { wrappedValue }, set: { new in wrappedValue = address ? SingleLineText.addressLive(new) : SingleLineText.lineBreaksRemoved(new) })
    }
}
