# Mygra

A SwiftUI app that helps people track migraines and related factors, then surfaces actionable insights. Mygra combines HealthKit data (sleep, hydration, caffeine, energy intake), local weather conditions via WeatherKit, and on-device intelligence to provide guidance through a dedicated Migraine Assistant.

## Features

- **Insights Dashboard**
  - Weather card powered by WeatherKit (temperature, pressure, humidity, conditions, location, last updated, pull-to-refresh)
  - "Quick Bits" insight feed highlighting notable patterns (e.g., hydration on migraine days, sleep trends)
  - Adaptive layout that places cards side-by-side on larger screens (iPad, landscape) and stacks on smaller screens

- **Today Card + Quick Add**
  - Connect to HealthKit and view the latest data for today
  - Quickly add: water (L/fl oz), caffeine (mg), food/energy (kcal), and sleep (h)
  - Writes entries to HealthKit and refreshes the dashboard

- **Migraine Assistant (Apple Intelligence)**
  - Opens a full-screen counselor-style chat to guide users with personalized advice
  - Launches only on devices that support Apple Intelligence capabilities

- **Haptics & Polished UX**
  - Light impacts for interactions, success/error feedback
  - Pull-to-refresh across insights, weather, and health data

## Tech Stack

- **SwiftUI** for the UI
- **Swift Concurrency** (async/await, Task groups) for async workflows
- **HealthKit** for reading/writing health data (water, caffeine, energy/food, sleep)
- **WeatherKit** for local conditions and metadata
- **App Storage** for unit preferences (metric/imperial)

## Architecture Overview

Mygra uses a lightweight, testable state management approach based on environment-provided managers and a local view model for transient UI state:

- `InsightManager` — Fetches and aggregates insights; coordinates the counselor chat; exposes `insights`, `errors`, and refresh state.
- `HealthManager` — Handles HealthKit authorization and CRUD; exposes `isAuthorized` and `latestData`; provides saving helpers (water, caffeine, energy, sleep).
- `WeatherManager` — Fetches and formats weather data; exposes strings for display, conditions, last updated, and refresh state.
- `InsightsView.ViewModel` — UI state for the Insights screen (quick add panel, input values, saving state, sheet/full-screen toggles).

The `InsightsView` composes:
- Weather card
- Intelligence card (conditionally shown)
- Today card with quick add
- Quick Bits insights list

Concurrency patterns include `async let` for initial loads and `TaskGroup` for parallel refreshes.

## Requirements

- Xcode 15 or later (recommended: Xcode 16/26 toolchain as applicable)
- iOS 17+ (project may target newer SDKs; adjust as needed)
- A device or simulator with HealthKit capability (note: HealthKit writes require a real device)
- WeatherKit entitlement and configuration (see below)
- Apple Intelligence features require compatible devices and OS versions

## Setup

1. **Clone the repository**
