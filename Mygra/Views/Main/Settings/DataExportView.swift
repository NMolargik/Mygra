//
//  DataExportView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI

struct DataExportView: View {
    let user: User
    let migraines: [Migraine]

    var body: some View {
        Button("Export Data") {
            let userCSV = DataExportUtility.exportUserToCSV(user: user)
            let migrainesCSV = DataExportUtility.exportMigrainesToCSV(migraines: migraines)
            
            // Save to files
            if let userURL = DataExportUtility.saveCSVToFile(content: userCSV, fileName: "user_data.csv"),
               let migrainesURL = DataExportUtility.saveCSVToFile(content: migrainesCSV, fileName: "migraine_data.csv") {
                // Present share sheet
                let activityController = UIActivityViewController(
                    activityItems: [userURL, migrainesURL],
                    applicationActivities: nil
                )
                // Present on iOS/iPadOS; adapt for macOS/watchOS as needed
                if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(activityController, animated: true)
                }
            }
        }
    }
}
