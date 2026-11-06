//
//  ExportFiles.swift
//  MygraServices
//
//  Writes exported reports to timestamped files in the temporary directory so they can
//  be shared or saved to Files.
//

import Foundation

nonisolated public enum ExportFiles {
    /// Writes `data` to `Mygra_Migraines_<timestamp>.<extension>` in the temp directory.
    public static func writeTemporaryFile(_ data: Data, fileExtension: String, now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mygra_Migraines_\(formatter.string(from: now))")
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }
}
