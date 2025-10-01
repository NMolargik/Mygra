import Foundation

extension DedupeKey {
    /// Stable string key combining fields; safe to use for lightweight caches.
    var key: String { "\(category.rawValue)|\(title)|\(message)" }
}
