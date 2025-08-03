//
//  WeatherWidget.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI
import WeatherKit
import CoreLocation

struct WeatherWidgetView: View {
    @State private var currentWeather: (pressure: Double, temperature: Double, humidity: Double)? = nil
    @State private var errorMessage: String? = nil
    @State private var locationManager = CLLocationManager()
    @State private var location: CLLocation? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Weather")
                .font(.headline)
            
            if let weather = currentWeather {
                HStack(spacing: 16) {
                    // Temperature
                    VStack {
                        Image(systemName: "thermometer.medium")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("\(weather.temperature, specifier: "%.1f")°C")
                            .font(.subheadline)
                    }
                    
                    // Humidity
                    VStack {
                        Image(systemName: "humidity")
                            .font(.largeTitle)
                            .foregroundColor(.cyan)
                        Text("\(weather.humidity, specifier: "%.0f")%")
                            .font(.subheadline)
                    }
                    
                    // Pressure
                    VStack {
                        Image(systemName: "gauge.with.needle")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("\(weather.pressure, specifier: "%.0f") hPa")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                
                if let warning = getPressureWarning(pressure: weather.pressure) {
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .font(.subheadline)
                    .foregroundColor(.red)
            } else {
                Text("Fetching weather...")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 2)
        .onAppear {
            fetchLocationAndWeather()
        }
    }
    
    private func fetchLocationAndWeather() {
        locationManager.requestWhenInUseAuthorization()
        if let loc = locationManager.location {
            location = loc
            Task {
                do {
                    let weather = try await WeatherManager().fetchWeather(for: Date(), location: loc)
                    currentWeather = weather
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            errorMessage = "Location unavailable"
        }
    }
    
    private func getPressureWarning(pressure: Double) -> String? {
        if pressure < 1000 {
            return "Low Pressure Warning: Potential migraine trigger due to pressure drop."
        } else if pressure > 1030 {
            return "High Pressure Warning: Potential migraine trigger due to high pressure."
        }
        return nil
    }
}

#Preview {
    WeatherWidgetView()
}
