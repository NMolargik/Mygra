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
                    // Keep a heading with the start of what follows (no stranded headings).
                    ensureRoom(110)
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
                case .table(let table):
                    drawTable(table, contentWidth: contentWidth, cursorY: { cursorY }, advance: { cursorY += $0 }, ensureRoom: ensureRoom)
                case .curve(let curve):
                    ensureRoom(curveHeight + 8)
                    drawCurve(curve, atY: cursorY, width: contentWidth)
                    cursorY += curveHeight + 8
                }
            }
        }
    }

    /// Writes the report to a timestamped file in the temporary directory.
    public static func writeTemporaryFile(_ data: Data, now: Date = Date()) throws -> URL {
        try ExportFiles.writeTemporaryFile(data, fileExtension: "pdf", now: now)
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

    // MARK: - Tables

    /// The cursor is passed as closures (not `inout`) because `ensureRoom` also mutates it
    /// when a row starts a new page; overlapping access to one variable traps at runtime.
    private static func drawTable(_ table: ReportTable, contentWidth: CGFloat, cursorY: () -> CGFloat, advance: (CGFloat) -> Void, ensureRoom: (CGFloat) -> Void) {
        guard !table.columns.isEmpty else { return }
        // The first column (labels) is wider than the numeric columns.
        let count = table.columns.count
        let firstWidth = count == 1 ? contentWidth : min(contentWidth * 0.34, 170)
        let otherWidth = count > 1 ? (contentWidth - firstWidth) / CGFloat(count - 1) : 0
        func columnX(_ index: Int) -> CGFloat { margin + (index == 0 ? 0 : firstWidth + otherWidth * CGFloat(index - 1)) }
        func columnWidth(_ index: Int) -> CGFloat { index == 0 ? firstWidth : otherWidth }

        func drawRow(_ cells: [String], font: UIFont, color: UIColor, background: UIColor?) {
            let height = cells.enumerated().map { index, text in
                ceil((text as NSString).boundingRect(
                    with: CGSize(width: columnWidth(index) - 6, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil
                ).height)
            }.max() ?? 14
            let rowHeight = max(height, 12) + 6
            ensureRoom(rowHeight)
            if let background, let cg = UIGraphicsGetCurrentContext() {
                cg.setFillColor(background.cgColor)
                cg.fill(CGRect(x: margin, y: cursorY(), width: contentWidth, height: rowHeight))
            }
            for (index, text) in cells.enumerated() where index < count {
                (text as NSString).draw(
                    with: CGRect(x: columnX(index) + 3, y: cursorY() + 3, width: columnWidth(index) - 6, height: rowHeight - 3),
                    options: [.usesLineFragmentOrigin], attributes: [.font: font, .foregroundColor: color], context: nil
                )
            }
            advance(rowHeight)
            drawDivider(atY: cursorY())
        }

        drawRow(table.columns, font: .systemFont(ofSize: 10, weight: .semibold), color: .black, background: UIColor(white: 0.93, alpha: 1))
        for (index, row) in table.rows.enumerated() {
            let highlighted = table.highlightedRows.contains(index)
            drawRow(
                row,
                font: .systemFont(ofSize: 10, weight: highlighted ? .semibold : .regular),
                color: highlighted ? UIColor(red: 0.7, green: 0.2, blue: 0.1, alpha: 1) : .darkGray,
                background: highlighted ? UIColor(red: 1, green: 0.95, blue: 0.9, alpha: 1) : nil
            )
        }
        advance(4)
    }

    // MARK: - Curves

    private static let curveHeight: CGFloat = 78

    /// A compact pain-over-time plot: title/subtitle on the left, plot on the right.
    private static func drawCurve(_ curve: ReportCurve, atY y: CGFloat, width: CGFloat) {
        let textWidth: CGFloat = 170
        let plot = CGRect(x: margin + textWidth + 14, y: y + 6, width: width - textWidth - 22, height: curveHeight - 20)
        draw(curve.title, at: y, width: textWidth, font: .systemFont(ofSize: 10, weight: .semibold), color: .black)
        (curve.subtitle as NSString).draw(
            with: CGRect(x: margin, y: y + 14, width: textWidth, height: 40),
            options: [.usesLineFragmentOrigin], attributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray], context: nil
        )
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        defer { cg.restoreGState() }

        // Grid at pain 0, 5, 10.
        cg.setLineWidth(0.4)
        cg.setStrokeColor(UIColor.lightGray.cgColor)
        for level in [0.0, 5.0, 10.0] {
            let gy = plot.maxY - plot.height * level / 10
            cg.move(to: CGPoint(x: plot.minX, y: gy))
            cg.addLine(to: CGPoint(x: plot.maxX, y: gy))
            cg.strokePath()
            ("\(Int(level))" as NSString).draw(
                at: CGPoint(x: plot.minX - 12, y: gy - 5),
                withAttributes: [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.gray]
            )
        }

        let maxMinutes = max(curve.points.map(\.minutes).max() ?? 0, 30)
        func point(_ p: ReportCurve.Point) -> CGPoint {
            CGPoint(x: plot.minX + plot.width * p.minutes / maxMinutes, y: plot.maxY - plot.height * min(max(p.pain, 0), 10) / 10)
        }
        let color = UIColor(red: 0.36, green: 0.31, blue: 0.85, alpha: 1)
        cg.setStrokeColor(color.cgColor)
        cg.setFillColor(color.cgColor)
        cg.setLineWidth(1.5)
        if let first = curve.points.first {
            cg.move(to: point(first))
            for p in curve.points.dropFirst() { cg.addLine(to: point(p)) }
            cg.strokePath()
        }
        for p in curve.points {
            let c = point(p)
            cg.fillEllipse(in: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4))
        }
        let label = MigraineDates.durationString(maxMinutes * 60)
        (label as NSString).draw(
            at: CGPoint(x: plot.maxX - 30, y: plot.maxY + 2),
            withAttributes: [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.gray]
        )
    }
}
#endif
