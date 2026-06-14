//
//  OnboardingLocationPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import CoreLocation

struct OnboardingLocationPage: View {
    @Environment(WeatherManager.self) private var weatherManager

    private var locationManager: LocationManager? { weatherManager.locationManager }

    private var state: PermissionState {
        guard let locationManager else { return .notRequested }

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notRequested
        @unknown default:
            return .notRequested
        }
    }

    private var statusConfig: (icon: String, color: Color, title: String, description: String) {
        guard locationManager != nil else {
            return (
                "location.circle.fill",
                .secondary,
                "Location Unavailable",
                "Location services aren't available right now. You can continue and enable location later in Settings."
            )
        }

        switch state {
        case .granted:
            return (
                "checkmark.circle.fill",
                .green,
                "Location Enabled",
                "We'll use your location for local weather."
            )
        case .denied:
            return (
                "location.slash.fill",
                .orange,
                "Location Disabled",
                "Enable location in Settings to get weather data."
            )
        case .notRequested:
            return (
                "location.circle.fill",
                .mygraBlue,
                "Enable Location",
                "Allow location access to see local weather on your home screen."
            )
        }
    }

    var body: some View {
        PermissionPageScaffold(
            state: state,
            icon: statusConfig.icon,
            iconColor: statusConfig.color,
            title: statusConfig.title,
            description: statusConfig.description,
            requestButtonTitle: "Allow Location Access",
            requestButtonIcon: "location.fill",
            requestButtonColor: .mygraBlue,
            isRequestEnabled: locationManager != nil,
            onRequest: {
                locationManager?.requestAuthorization()
            }
        ) {
            PermissionFeatureRow(
                icon: "sun.max.fill",
                iconColor: .yellow,
                title: "Local Weather",
                description: "See current conditions on your dashboard."
            )
        }
    }
}

#Preview {
    OnboardingLocationPage()
        .environment(WeatherManager(locationManager: LocationManager()))
}
