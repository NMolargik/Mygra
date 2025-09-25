//
//  HealthDetailView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct HealthDetailView: View {
    let health: HealthData
    let useMetricUnits: Bool
    
    var body: some View {
        InfoDetailView(title: "Health") {
            VStack(alignment: .leading, spacing: 8) {
                if let w = health.waterLiters {
                    LabeledRow("Water") {
                        HStack(spacing: 8) {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(.blue)
                            Group {
                                if useMetricUnits {
                                    Text(String(format: "%.1f L", w))
                                } else {
                                    let flOz = w * 33.8140227
                                    Text(String(format: "%.0f fl oz", flOz))
                                }
                            }
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.blue.opacity(0.14)))
                        }
                    }
                }
                if let s = health.sleepHours {
                    LabeledRow("Sleep") {
                        HStack(spacing: 8) {
                            Image(systemName: "bed.double.fill")
                                .foregroundStyle(.indigo)
                            Text(String(format: "%.1f h", s))
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                        }
                    }
                }
                if let kcal = health.energyKilocalories {
                    LabeledRow("Food") {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(.orange)
                            Text(String(format: "%.0f cal", kcal))
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.orange.opacity(0.14)))
                        }
                    }
                }
                if let caf = health.caffeineMg {
                    LabeledRow("Caffeine") {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundStyle(.brown)
                            Text(String(format: "%.0f mg", caf))
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.brown.opacity(0.14)))
                        }
                    }
                }
                if let steps = health.stepCount {
                    LabeledRow("Steps") {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .foregroundStyle(.green)
                            Text("\(steps)")
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.green.opacity(0.14)))
                        }
                    }
                }
                if let rhr = health.restingHeartRate {
                    LabeledRow("Resting HR") {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("\(rhr) bpm")
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.red.opacity(0.14)))
                        }
                    }
                }
                if let ahr = health.activeHeartRate {
                    LabeledRow("Active HR") {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.heart.fill")
                                .foregroundStyle(.pink)
                            Text("\(ahr) bpm")
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.pink.opacity(0.14)))
                        }
                    }
                }
                if let phase = health.menstrualPhase {
                    LabeledRow("Menstrual Phase") {
                        HStack(spacing: 8) {
                            Image(systemName: "drop.triangle.fill")
                                .foregroundStyle(.purple)
                            Text(phase.rawValue)
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.purple.opacity(0.14)))
                        }
                    }
                }
                if let glucose = health.glucoseMgPerdL {
                    LabeledRow("Glucose") {
                        HStack(spacing: 8) {
                            Image(systemName: "cross.case.fill")
                                .foregroundStyle(.mint)
                            Group {
                                if useMetricUnits {
                                    let mmol = glucose / 18.0
                                    Text(String(format: "%.1f mmol/L", mmol))
                                } else {
                                    Text(String(format: "%.0f mg/dL", glucose.rounded()))
                                }
                            }
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.mint.opacity(0.14)))
                        }
                    }
                }
                if let spo2Fraction = health.bloodOxygenPercent {
                    let percent = spo2Fraction * 100.0
                    LabeledRow("Oxygen Saturation") {
                        HStack(spacing: 8) {
                            Image(systemName: "lungs.fill")
                                .foregroundStyle(.cyan)
                            Group {
                                if percent.truncatingRemainder(dividingBy: 1) == 0 {
                                    Text("\(Int(percent))%")
                                } else {
                                    Text(String(format: "%.1f%%", percent))
                                }
                            }
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.cyan.opacity(0.14)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    HealthDetailView(health: HealthData(), useMetricUnits: false)
}
