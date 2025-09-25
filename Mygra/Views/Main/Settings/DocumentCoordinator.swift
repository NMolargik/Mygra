//
//  DocumentCoordinator.swift
//  Mygra
//
//  Created by Nick Molargik on 9/25/25.
//

import Foundation
import UIKit

final class DocumentCoordinator: NSObject, UIDocumentPickerDelegate {
    let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onDismiss()
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onDismiss()
    }
}
