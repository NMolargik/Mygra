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
                    MetricRowView("Water") {
                        HStack(spacing: 8) {
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
                            Image(systemName: "drop.fill")
                                .frame(width: 30)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                if let s = health.sleepHours {
                    MetricRowView("Sleep") {
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f h", s))
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                            Image(systemName: "bed.double.fill")
                                .frame(width: 30)
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                if let kcal = health.energyKilocalories {
                    MetricRowView("Food") {
                        HStack(spacing: 8) {
                            Text(String(format: "%.0f cal", kcal))
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.orange.opacity(0.14)))
                            Image(systemName: "fork.knife")
                                .frame(width: 30)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                if let caf = health.caffeineMg {
                    MetricRowView("Caffeine") {
                        HStack(spacing: 8) {
                            Text(String(format: "%.0f mg", caf))
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.brown.opacity(0.14)))
                            Image(systemName: "cup.and.saucer.fill")
                                .frame(width: 30)
                                .foregroundStyle(.brown)
                        }
                    }
                }
                if let steps = health.stepCount {
                    MetricRowView("Steps") {
                        HStack(spacing: 8) {
                            Text("\(steps)")
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.green.opacity(0.14)))
                            Image(systemName: "figure.walk")
                                .frame(width: 30)
                                .foregroundStyle(.green)
                        }
                    }
                }
                if let rhr = health.restingHeartRate {
                    MetricRowView("Resting HR") {
                        HStack(spacing: 8) {
                            Text("\(rhr) bpm")
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.red.opacity(0.14)))
                            Image(systemName: "heart.fill")
                                .frame(width: 30)
                                .foregroundStyle(.red)
                        }
                    }
                }
                if let ahr = health.activeHeartRate {
                    MetricRowView("Active HR") {
                        HStack(spacing: 8) {
                            Text("\(ahr) bpm")
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.pink.opacity(0.14)))
                            Image(systemName: "bolt.heart.fill")
                                .frame(width: 30)
                                .foregroundStyle(.pink)
                        }
                    }
                }
                if let phase = health.menstrualPhase {
                    MetricRowView("Menstrual Phase") {
                        HStack(spacing: 8) {
                            Text(phase.rawValue)
                                .font(.callout).bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.purple.opacity(0.14)))
                            Image(systemName: "drop.triangle.fill")
                                .frame(width: 30)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                if let glucose = health.glucoseMgPerdL {
                    MetricRowView("Glucose") {
                        HStack(spacing: 8) {
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
                            Image(systemName: "cross.case.fill")
                                .frame(width: 30)
                                .foregroundStyle(.mint)
                        }
                    }
                }
                if let spo2Fraction = health.bloodOxygenPercent {
                    let percent = spo2Fraction * 100.0
                    MetricRowView("Oxygen Saturation") {
                        HStack(spacing: 8) {
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
                            Image(systemName: "lungs.fill")
                                .frame(width: 30)
                                .foregroundStyle(.cyan)
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
