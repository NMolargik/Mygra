//
//  DocumentPickerView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/8/25.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeCoordinator() -> DocumentCoordinator {
        DocumentCoordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
}

private struct DocumentPickerPreviewHost: View {
    @State private var tmpURL: URL
    init() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewExport", conformingTo: .pdf)
        // Ensure a small file exists for export
        if !FileManager.default.fileExists(atPath: tmp.path) {
            let sample = Data("%PDF-1.4\n%âãÏÓ\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF".utf8)
            try? sample.write(to: tmp, options: .atomic)
        }
        _tmpURL = State(initialValue: tmp)
    }
    var body: some View {
        DocumentPickerView(url: tmpURL, onDismiss: {})
            .ignoresSafeArea() // so the UIKit picker can present correctly in preview
    }
}

#Preview("Document Export") {
    DocumentPickerPreviewHost()
}
