//
//  PDFComposer.swift
//  Mygra
//
//  Created by Nick Molargik on 9/8/25.
//

internal import CoreGraphics
import Foundation
import UIKit
import WeatherKit

enum PDFComposer {
    static func composePDF(
        user: User?,
        migraines: [Migraine],
        useMetricUnits: Bool,
        useDMY: Bool
    ) throws -> Data {
        #if os(iOS)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in
            func startPage() {
                ctx.beginPage()
                // Ensure visible white background
                if let cg = UIGraphicsGetCurrentContext() {
                    cg.setFillColor(UIColor.white.cgColor)
                    cg.fill(pageRect)
                }
            }

            var cursorY: CGFloat = 36
            let leftX: CGFloat = 36
            let rightMargin: CGFloat = 36
            let contentWidth = pageRect.width - leftX - rightMargin

            func startPageIfNeeded(extra: CGFloat) {
                if cursorY + extra > pageRect.height - 36 {
                    startPage()
                    cursorY = 36
                }
            }

            // Start first page
            startPage()

            // Header
            cursorY += drawTitle("Mygra Export", at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
            cursorY += 8
            let exportStamp = DateFormatting.dateTime(Date(), useDMY: useDMY)
            cursorY += drawSubheadline("Exported \(exportStamp)", at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
            cursorY += 16

            // User section
            if let u = user {
                cursorY += drawSectionHeader("User", at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
                cursorY += 6
                let heightValue = u.displayHeight(useMetricUnits: useMetricUnits) ?? 0
                let weightValue = u.displayWeight(useMetricUnits: useMetricUnits) ?? 0
                let heightUnit = useMetricUnits ? "cm" : "in"
                let weightUnit = useMetricUnits ? "kg" : "lb"

                let lines: [String] = [
                    "Name: \(u.name.isEmpty ? "—" : u.name)",
                    "Birthday: \(DateFormatting.date(u.birthday, useDMY: useDMY))",
                    "Biological Sex: \(u.biologicalSex.rawValue.capitalized)",
                    String(format: "Height: %.1f %@", heightValue, heightUnit),
                    String(format: "Weight: %.1f %@", weightValue, weightUnit),
                    String(format: "Avg Sleep: %.1f h", u.averageSleepHours),
                    String(format: "Avg Caffeine: %.0f mg", u.averageCaffeineMg),
                    "Chronic Conditions: \(u.chronicConditions.isEmpty ? "—" : u.chronicConditions.joined(separator: ", "))",
                    "Dietary Restrictions: \(u.dietaryRestrictions.isEmpty ? "—" : u.dietaryRestrictions.joined(separator: ", "))"
                ]
                for line in lines {
                    startPageIfNeeded(extra: 18)
                    cursorY += drawBody(line, at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
                }
                cursorY += 12
            }

            // Migraine list section
            cursorY += drawSectionHeader("Migraines (\(migraines.count))", at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
            cursorY += 6

            if migraines.isEmpty {
                cursorY += drawBody("No migraines recorded.", at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
            } else {
                for (idx, m) in migraines.enumerated() {
                    // Each entry block
                    startPageIfNeeded(extra: 100)

                    let title = "• \(DateFormatting.dateTime(m.startDate, useDMY: useDMY))" + (m.pinned ? "  [Pinned]" : "")
                    cursorY += drawSubheadline(title, at: CGPoint(x: leftX, y: cursorY), width: contentWidth)

                    var meta: [String] = []
                    if let end = m.endDate {
                        let interval = DateFormatting.dateInterval(from: m.startDate, to: end, useDMY: useDMY)
                        meta.append("Range: \(interval)")
                        let dur = end.timeIntervalSince(m.startDate)
                        let h = Int(dur) / 3600
                        let min = (Int(dur) % 3600) / 60
                        let s = Int(dur) % 60
                        if h > 0 {
                            meta.append(String(format: "Duration: %dh %02dm %02ds", h, min, s))
                        } else {
                            meta.append(String(format: "Duration: %dm %02ds", min, s))
                        }
                    } else {
                        meta.append("Ongoing")
                    }
                    meta.append("Pain: \(m.painLevel)")
                    meta.append("Stress: \(m.stressLevel)")

                    if !m.triggers.isEmpty {
                        let names = m.triggers.map { $0.displayName }
                        meta.append("Triggers: \(names.joined(separator: ", "))")
                    }
                    if !m.customTriggers.isEmpty {
                        meta.append("Custom Triggers: \(m.customTriggers.joined(separator: ", "))")
                    }
                    if !m.foodsEaten.isEmpty {
                        meta.append("Foods: \(m.foodsEaten.joined(separator: ", "))")
                    }
                    if let note = m.note, !note.isEmpty {
                        meta.append("Note: \(note)")
                    }
                    if let wx = m.weather {
                        var wparts: [String] = []
                        wparts.append("Condition: \(wx.condition.description)")
                        let temp = wx.displayTemperature(useMetricUnits: useMetricUnits)
                        wparts.append(String(format: "Temp: %.0f%@", temp, useMetricUnits ? "°C" : "°F"))
                        wparts.append("Humidity: \(Int(wx.humidityPercent))%")
                        let pressure = wx.displayBarometricPressure(useMetricUnits: useMetricUnits)
                        if useMetricUnits {
                            wparts.append(String(format: "Pressure: %.0f hPa", pressure))
                        } else {
                            wparts.append(String(format: "Pressure: %.2f inHg", pressure))
                        }
                        if let place = wx.locationDescription, !place.isEmpty {
                            wparts.append("Location: \(place)")
                        }
                        meta.append("Weather: " + wparts.joined(separator: ", "))
                    }
                    if let h = m.health {
                        var hparts: [String] = []
                        if let liters = h.waterLiters {
                            if useMetricUnits {
                                hparts.append(String(format: "Water: %.1f L", liters))
                            } else {
                                let flOz = liters * 33.8140227
                                hparts.append(String(format: "Water: %.0f fl oz", flOz))
                            }
                        }
                        if let hours = h.sleepHours {
                            hparts.append(String(format: "Sleep: %.1f h", hours))
                        }
                        if let kcal = h.energyKilocalories {
                            hparts.append(String(format: "Food: %.0f cal", kcal))
                        }
                        if let caf = h.caffeineMg {
                            hparts.append(String(format: "Caffeine: %.0f mg", caf))
                        }
                        if let steps = h.stepCount {
                            hparts.append("Steps: \(steps)")
                        }
                        if let rhr = h.restingHeartRate {
                            hparts.append("Resting HR: \(rhr) bpm")
                        }
                        if let ahr = h.activeHeartRate {
                            hparts.append("Active HR: \(ahr) bpm")
                        }
                        if let phase = h.menstrualPhase {
                            hparts.append("Menstrual Phase: \(phase.rawValue)")
                        }
                        if let glucose = h.glucoseMgPerdL {
                            if useMetricUnits {
                                let mmol = glucose / 18.0
                                hparts.append(String(format: "Glucose: %.1f mmol/L", mmol))
                            } else {
                                hparts.append(String(format: "Glucose: %.0f mg/dL", glucose.rounded()))
                            }
                        }
                        if let spo2Fraction = h.bloodOxygenPercent {
                            let percent = spo2Fraction * 100.0
                            if percent.truncatingRemainder(dividingBy: 1) == 0 {
                                hparts.append("O2: \(Int(percent))%")
                            } else {
                                hparts.append(String(format: "O2: %.1f%%", percent))
                            }
                        }
                        if !hparts.isEmpty {
                            meta.append("Health: " + hparts.joined(separator: ", "))
                        }
                    }

                    // Draw meta lines
                    for line in meta {
                        startPageIfNeeded(extra: 18)
                        cursorY += drawBody(line, at: CGPoint(x: leftX, y: cursorY), width: contentWidth)
                    }

                    // Spacing between entries
                    cursorY += 12

                    // Divider between entries (light)
                    if idx < migraines.count - 1 {
                        startPageIfNeeded(extra: 20)
                        drawDivider(atY: cursorY - 6, left: leftX, right: pageRect.width - rightMargin)
                    }
                }
            }
        }
        return data
        #else
        return Data()
        #endif
    }

    // Drawing helpers (CoreGraphics/TextKit-lite)
    @discardableResult
    private static func drawTitle(_ text: String, at origin: CGPoint, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        return draw(text, at: origin, width: width, attributes: attrs)
    }

    @discardableResult
    private static func drawSectionHeader(_ text: String, at origin: CGPoint, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        return draw(text, at: origin, width: width, attributes: attrs)
    }

    @discardableResult
    private static func drawSubheadline(_ text: String, at origin: CGPoint, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        return draw(text, at: origin, width: width, attributes: attrs)
    }

    @discardableResult
    private static func drawBody(_ text: String, at origin: CGPoint, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        return draw(text, at: origin, width: width, attributes: attrs)
    }

    @discardableResult
    private static func draw(_ text: String, at origin: CGPoint, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let nsText = text as NSString
        let bounding = nsText.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let height = max(ceil(bounding.height), 14) // ensure a minimum line height
        nsText.draw(with: CGRect(x: origin.x, y: origin.y, width: width, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil)
        return height
    }

    private static func drawDivider(atY y: CGFloat, left: CGFloat, right: CGFloat) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: left, y: y))
        ctx.addLine(to: CGPoint(x: right, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }
}
