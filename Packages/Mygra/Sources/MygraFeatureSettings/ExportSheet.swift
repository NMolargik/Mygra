//
//  ExportSheet.swift
//  MygraFeatureSettings
//
//  What appears once a report has been written: the file, a share action (Messages,
//  Mail, AirDrop, a doctor's portal…), and Save to Files through the document picker.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

nonisolated enum ExportKind: Sendable {
    case pdf
    case csv
}

/// A finished export waiting to be shared or saved.
nonisolated struct PendingExport: Identifiable, Sendable {
    let kind: ExportKind
    let url: URL
    var id: URL { url }
}

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let export: PendingExport

    @State private var showDocumentPicker = false

    private var title: LocalizedStringKey {
        switch export.kind {
        case .pdf: "PDF Report Ready"
        case .csv: "CSV Export Ready"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch export.kind {
        case .pdf: "A clinical summary with headache days, medication use, questionnaire scores, and every attack."
        case .csv: "Every migraine as a spreadsheet row, with health and weather columns."
        }
    }

    private var systemImage: String {
        switch export.kind {
        case .pdf: "doc.richtext.fill"
        case .csv: "tablecells.fill"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Brand.Space.lg) {
                Spacer(minLength: 0)
                Image(systemName: systemImage)
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(LinearGradient.mygraHorizontal)
                    .accessibilityHidden(true)
                VStack(spacing: Brand.Space.xs) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(export.url.lastPathComponent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)

                ShareLink(item: export.url, preview: SharePreview(export.url.lastPathComponent, image: Image(systemName: systemImage))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionButton()
                .simultaneousGesture(TapGesture().onEnded { Haptics.lightImpact() })
                .accessibilityIdentifier("export.share")

                Button {
                    Haptics.lightImpact()
                    showDocumentPicker = true
                } label: {
                    Label("Save to Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionButton()
                .accessibilityIdentifier("export.save")
            }
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(Brand.Space.xl)
            .background(LinearGradient.mygraWash.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.lightImpact()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(url: export.url) {
                    showDocumentPicker = false
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG
#Preview("PDF") {
    ExportSheet(export: PendingExport(kind: .pdf, url: URL(fileURLWithPath: "/tmp/Mygra_Migraines_2026-11-06_09-00-00.pdf")))
}
#endif
#endif
