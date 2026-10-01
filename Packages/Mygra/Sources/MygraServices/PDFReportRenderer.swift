//
//  PDFReportRenderer.swift
//  MygraServices
//
//  Draws `MigraineReport` blocks into a US-Letter PDF with UIKit. The text itself is
//  assembled (and tested) in MygraCore.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import UIKit
import MygraCore

nonisolated public enum PDFReportRenderer {
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 36

    /// Renders the blocks to PDF data, paginating as needed.
    public static func render(_ blocks: [ReportBlock]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        return renderer.pdfData { context in
            let contentWidth = pageRect.width - margin * 2
            var cursorY = margin

            func startPage() {
                context.beginPage()
                if let cg = UIGraphicsGetCurrentContext() {
                    cg.setFillColor(UIColor.white.cgColor)
                    cg.fill(pageRect)
                }
                cursorY = margin
            }

            func ensureRoom(_ height: CGFloat) {
                if cursorY + height > pageRect.height - margin {
                    startPage()
                }
            }

            startPage()

            for block in blocks {
                switch block {
                case .title(let text):
                    ensureRoom(30)
                    cursorY += draw(text, at: cursorY, width: contentWidth, font: .systemFont(ofSize: 24, weight: .bold), color: .black)
                case .sectionHeader(let text):
                    ensureRoom(24)
                    cursorY += draw(text, at: cursorY, width: contentWidth, font: .systemFont(ofSize: 18, weight: .semibold), color: .black)
                case .subheadline(let text):
                    ensureRoom(20)
                    cursorY += draw(text, at: cursorY, width: contentWidth, font: .systemFont(ofSize: 14, weight: .semibold), color: .black)
                case .body(let text):
                    ensureRoom(18)
                    cursorY += draw(text, at: cursorY, width: contentWidth, font: .systemFont(ofSize: 12), color: .darkGray)
                case .spacer(let height):
                    cursorY += height
                case .divider:
                    ensureRoom(20)
                    drawDivider(atY: cursorY - 6)
                }
            }
        }
    }

    /// Writes the report to a timestamped file in the temporary directory.
    public static func writeTemporaryFile(_ data: Data, now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mygra_Migraines_\(formatter.string(from: now)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    private static func draw(_ text: String, at y: CGFloat, width: CGFloat, font: UIFont, color: UIColor) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let nsText = text as NSString
        let bounding = nsText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let height = max(ceil(bounding.height), 14)
        nsText.draw(
            with: CGRect(x: margin, y: y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return height
    }

    private static func drawDivider(atY y: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        context.strokePath()
        context.restoreGState()
    }
}
#endif
