# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mygra is a migraine-tracking app (migraines → intensity samples, with Health and weather snapshots, user tags, and rule-based + Apple Intelligence insights) built with SwiftUI + SwiftData and iCloud/CloudKit private-database sync. It ships an iOS app, a days-since-last-migraine home-screen widget, an ongoing-migraine Live Activity, and an Apple Watch companion with its own complication.

The app is a **thin app target on top of an SPM umbrella package** (`Packages/Mygra`) of layered, single-responsibility modules — the same clean architecture as Stork/Waffle/SetDeck/SCOUT. Dependencies point **inward**: features depend on the design system and core; data implements core's protocols; **core depends on nothing** (Foundation + SwiftData only).

## Build & Run

**Open `Mygra.xcworkspace`** (not the bare `.xcodeproj`) — it resolves the local package. No external dependencies. Xcode 27 / Swift 6.4.

**Swift 6 language mode**, MainActor default isolation everywhere: app/widget/watch targets set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; package targets use `swiftSettings: [.defaultIsolation(MainActor.self)]`. `#MemberImportVisibility` is on: every file must import the module defining any member it uses (`import os` for `Log`, `import MygraServices` for `HealthManager` members). Deployment floors: **iOS 18 / watchOS 10** — package platforms use string initializers (`.iOS("18.0"), .watchOS("10.0"), .macOS("15.0")`; macOS is the host-test floor). iOS-26-only APIs (`glassEffect`, `.glass` button styles, FoundationModels) stay behind `#available`/`canImport` guards.

Fast iteration — the package builds and tests on the macOS host, simulator-free:
```
cd Packages/Mygra && swift build && swift test        # domain/data/services/shared-model/composition logic
```
Verify iOS UI compiles (feature view files are gated `#if os(iOS)`):
```
cd Packages/Mygra && xcodebuild -scheme MygraComposition -destination 'generic/platform=iOS Simulator' build
```
Build the whole product (app + widget extension + watch app + watch widget):
```
xcodebuild -workspace Mygra.xcworkspace -scheme Mygra \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Requirements:** real device for HealthKit writes, Apple Intelligence, and WeatherKit; WeatherKit entitlement; iCloud container `iCloud.com.molargiksoftware.Mygra`; App Group `group.com.molargiksoftware.Mygra` (widget/watch status + App Intent hand-off).

## Architecture — `Packages/Mygra`

```
   ┌────────────── Mygra (app target — thin) ─────────────────┐
   │ MygraApp (@main) builds SessionController · Intents ·     │
   │ SpotlightIndexer · IntentDonor · AppStoreReviewRequester  │
   │ · BackgroundWeatherRefresh (BGTask) · MygraCommands       │
   ├────────── MygraWidgetsExtension ──────────────────────────┤
   │ days-since widget · Live Activity (attrs from Services)   │
   ├────────── Mygra Wrist Watch App + Wrist Widgets ──────────┤
   │ PhoneBridge (WatchConnectivity) over the Core wire types  │
   └──────────────────────────┬────────────────────────────────┘
                              │ app hosts RootView, registers session
   ┌──────────────────────────▼────────────────────────────────┐
   │ MygraComposition — SessionController (composition root)   │
   │ + RootView (stage machine) + MainView (tabs/split) + Splash│
   └──┬──────────────────────────────────┬─────────────────────┘
 ┌────▼─────────────┐  ┌──────────────┐  ┌▼───────────────────┐
 │ MygraFeature*    │  │ Mygra-       │  │ MygraData          │
 │ Dashboard ·      │  │ Services     │  │ Default*Repository │
 │ Calendar ·       │  │ HealthManager│  │ · MygraStore       │
 │ Migraines ·      │  │ WeatherMgr · │  │ (CloudKit, graceful│
 │ Assistant ·      │  │ LocationMgr ·│  │ degradation) ·     │
 │ Settings ·       │  │ Notification-│  │ SampleMigraineData │
 │ Onboarding       │  │ Mgr · Cloud- │  │ (DEBUG)            │
 ├──────────────────┤  │ Sync · Phone-│  └─────────┬──────────┘
 │ MygraFeature-    │  │ Connectivity │            │ implements
 │ Shared           │  │ · Intelligen-│            │
 │ MigraineDataModel│  │ ceService ·  │            │
 │ TagDataModel ·   │  │ LiveActivity-│            │
 │ UserDataModel ·  │  │ Controller · │            │
 │ InsightModel ·   │  │ WeatherRisk- │            │
 │ shared views ·   │  │ Notifier ·   │            │
 │ PreviewEnvironment│ │ PDFReport-   │            │
 └───┬──────────┬───┘  │ Renderer     │            │
     │ uses     │ uses  └──────┬───────┘            │
 ┌───▼──────┐ ┌─▼─────────────▼────────────────────▼───────────┐
 │ MygraDS  │ │ MygraCore (pure domain)                         │
 │ colors · │ │ @Model types · enums · domain (InsightRules/    │
 │ Brand    │ │ MigraineStatistics/WeatherRisk/MigraineReport/  │
 │ tokens · │ │ MigraineStatusSync) · DeepLink · watch wire     │
 │ toast ·  │ │ types · repository & use-case PROTOCOLS ·       │
 │ haptics ·│ │ MigraineChangeCenter · seams · Log              │
 │ components│└─────────────────────────────────────────────────┘
 └──────────┘
```

### MygraCore (pure — Foundation + SwiftData only, host-tested)
- **Models** (`@Model`): `Migraine` → `IntensitySample`, `WeatherData`, `HealthData`, `MigraineTag` (many-to-many), `User` (single row, folded on read). CloudKit rules: defaults on all attributes, optional relationships, no unique constraints; new properties must be additive.
- **`SkyCondition`** replaces WeatherKit's `WeatherCondition` inside the persisted model. Its raw values mirror WeatherKit's case names one-for-one so existing records decode unchanged; the mapping (`SkyCondition(_ WeatherCondition)`) lives in Services. **Never rename a case.**
- **Enumerations** (`nonisolated`, `Sendable`): `Severity`, `MigraineTrigger` (+`Group`, `grouped`, `triggers(in:matching:)`), `MenstrualPhase`, `BiologicalSex`, `InsightCategory/Priority`, `DashboardStat` (storage key + default visibility; color in DS), `AppStage`, `AppTab`, `OnboardingStep` (order/skippable rules), `DeepLink` (pure `init?(url:)` + App Group hand-off).
- **Domain**: `InsightRules` (every rule takes `now`/`calendar`), `MigraineStatistics`, `MigraineDates` (day math, elapsed/duration strings, the Health sampling window), `MigraineFilter` (+`matches`), `WeatherRisk` (thresholds + `shouldNotify` transition policy), `MigraineReport` (export as pure `ReportBlock`s; PDF drawing is in Services), `IntakeAdditions` (staged water/caffeine/food/sleep + slider geometry), `ReviewMilestone`, `DateFormatting`, `UnitConversion`, `MigraineStatusSync` (keeps App Group status, widgets, watch, and the Live Activity in step with the store by observing the change stream).
- **Services (protocols only)**: `MigraineRepository`/`TagRepository`/`UserRepository` + single-verb use-cases (`LoadMigraines`, `FindMigraine`, `CountMigraines`, `LogMigraine`, `StartMigraine`, `UpdateMigraine`, `EndOngoingMigraine`, `DeleteMigraine`, `DeleteAllMigraines`, `RecordIntensitySample`, `RemoveIntensitySample`, `LoadTags`/`CreateTag`/`UpdateTag`/`DeleteTag`/`ReorderTags`/`AssignTags`, `LoadUser`/`SaveUser`/`UpdateUser`/`DeleteUser`, `ObserveMigraineChanges`, DEBUG `GenerateSampleData` — each a `protocol` + `…UseCase` struct with `callAsFunction`). `LogMigraine` is the primary user action (persist + Health headache write for completed attacks + Siri donation for ongoing ones); `EndOngoingMigraine` is shared by the detail screen, the watch, Siri, and the menu bar. Nothing outside the composition root touches a repository directly (even App Intents).
- **Typed errors**: the persistence boundary declares `throws(PersistenceError)` (`.fetchFailed`/`.saveFailed`/`.notFound`) — new repository/use-case methods must keep the typed signature.
- **Change stream**: `MigraineChangeCenter` yields `MigraineChange` payloads (`migraineLogged(id)`, `migraineUpdated`, `migraineDeleted`, `tagsChanged`, `userChanged`, `bulk`). Repositories notify on every successful write and `CloudSyncManager` notifies `.bulk` on CloudKit imports; the data models, `InsightModel` (which analyzes `migraineLogged` records), `MigraineStatusSync`, and Spotlight all observe the one multicast `AsyncStream`. Never add per-screen refresh callbacks or NotificationCenter posts.
- **Seams**: `KeyValueStoring` (+`UserDefaults`), `WidgetTimelineReloading`, `WatchStatusPushing`, `MigraineActivityControlling`, `HeadacheRecording`, `MigraineIndexing` (Spotlight — impl app-side), `IntentDonating` (app-side), `ReviewRequesting` (app-side), `LocalNotifying`, `CurrentWeatherProviding`, `MigraineIntelligence`.
- **Watch wire protocol**: `WatchMessageKey`, `WatchRequest`, `WatchCommand`, `WatchMessage`, `WatchCommandReply`, and `SharedMigraineStatus.payload` — one definition linked by the phone relay and the watch app.
- `Log` — `os.Logger` per category. **Never `print`.**

### MygraData (persistence impl, depends on Core)
`DefaultMigraineRepository` (seeds the initial intensity sample on insert; `addIntensitySample` moves the headline levels), `DefaultTagRepository` (contiguous `sortIndex`, detaches before delete), `DefaultUserRepository` (folds duplicates), `MygraStore.makeContainer(inMemory:)` — **CloudKit → local → in-memory graceful degradation** (container id `iCloud.com.molargiksoftware.Mygra`) plus `makeTemporaryContainer()` for tests/previews. `SampleMigraineData` (DEBUG): six tags + 13 migraines over four weeks with health, weather, and intensity curves.

### MygraServices (system frameworks, depend on Core)
`HealthManager` (`#if canImport(HealthKit) && !os(macOS)`: authorization, `HealthData` snapshots for a window, `save(IntakeAdditions)`, `recordHeadache`; `HealthStore` seam), `WeatherManager` (WeatherKit + CoreLocation; exposes a Core-typed `WeatherReading`, 1-hour cooldown, reverse geocoding; `CurrentWeatherProviding`), `LocationManager`, `NotificationManager` (`LocalNotifying`; the center is lazy because it traps in unbundled test processes), `WeatherRiskNotifier` (refresh + notify on the transition into risk), `CloudSyncManager` (NSPersistentCloudKitContainer events + remote-change pings → change center), `PhoneConnectivityManager` (`WatchStatusPushing`; services watch commands through use-cases; delegate callbacks are `nonisolated` and extract Sendable values before hopping), `IntelligenceService` (FoundationModels behind `MigraineIntelligence`; `IntelligencePrompts` are pure and tested), `MigraineActivityAttributes` + `LiveActivityController` (ActivityKit, iOS only), `WidgetCenterReloader`, `PDFReportRenderer` (UIKit drawing of `ReportBlock`s).

### MygraDesignSystem (depends on Core)
Brand colors **in code** (`Color.mygraBlue`/`.mygraPurple`, `LinearGradient.mygra/.mygraWash/.mygraHorizontal`, `AngularGradient.appleIntelligence`), `Brand.Space`/`Brand.Radius`/`readableWidth`, `Color(hex:)`/`toHex()`, `Haptics` (no-op off-UIKit), toast stack (`ToastStyle`/`ToastItem`/`ToastManager`/`ToastView`/`.toastContainer()`), surface modifiers (`cardSurface`, `cardStyle`, `glassActionButton`, `adaptiveGlass`, `statPillBackground`, `shimmer`, `if`), components (`InsightCard`, `InfoDetailView`, `MetricRowView`, `MetricChip`, `InfoPillView`, `StatTileView`, `DetailRowView`, `AppleIntelligenceSymbol/Badge`, `WeatherAttributionView`, `SparkleText`, `TypingIndicator`), platform background colors, and Core styling extensions (`Severity.color`, `AppTab.icon()/color()`, `DashboardStat.color`, `InsightPriority.color`, `InsightCategory.systemImage`, `MenstrualPhase` icon/color, `MigraineTag.color`, `SkyCondition.symbolView()`). **Do not** hand-roll tinted glass pills; use `glassActionButton` and reserve `prominent` for the single primary action per context.

### MygraFeatureShared (depends on Core + DesignSystem + Services)
- **`MigraineDataModel`** — the environment-injected migraine surface (successor to MigraineManager): cached `migraines`/`ongoingMigraine`, `filter` → `visibleMigraines`, and verbs that each go through a use-case, refresh the cache synchronously, and surface failures as error toasts (never `try?`-swallowed); the change stream refreshes it for writes made elsewhere (CloudKit, intents, watch). Also owns the fifth-migraine review prompt via `ReviewMilestone`.
- **`TagDataModel`**, **`UserDataModel`** — same shape for tags and the profile.
- **`InsightModel`** — Quick Bits from `InsightRules`, per-migraine Apple Intelligence analysis (reacts to `migraineLogged`), Quick Bit explanations (cached), and the analyst chat, all through the `MigraineIntelligence` seam. Generated explanations stay pinned above the rule-based cards.
- **Shared views**: `IntakeEditorView`, `IntakeSection`, `DurationSection`, `TriggerPickerSection`, `SearchField`, `LevelSlider`.
- **`PreviewEnvironment`** (DEBUG): in-memory repositories behind the production use-cases + every environment object; `.previewEnvironment()` is how feature previews get their graph.

### MygraFeature* (one per screen, depend on Core + DesignSystem + FeatureShared [+ Services])
`Dashboard` (weather, assistant entry, Today card with Quick Add, Quick Bits; hosts Calendar/Settings/Assistant sheets on regular widths → depends on those three), `Calendar`, `Migraines` (list + filter, entry form with `ViewModel`, detail with chart/sheets and `MigraineEdits`), `Assistant`, `Settings` (units, dashboard stats, tags, profile, PDF export, delete-all, DEBUG sample data), `Onboarding` (embeds `UserEditView` from Settings). Views are `#if os(iOS)`-gated and read `@Environment(MigraineDataModel.self)` / `@Environment(HealthManager.self)` etc.; `RootView` injects everything.

### MygraComposition (top of graph — the composition root)
`SessionController` (`@MainActor @Observable`) builds the whole graph in `init` (container → change center → repositories → use-cases → shared models → managers → `MigraineStatusSync`), owns `pendingDeepLink` (consumed by `MainView`; set by `onOpenURL`, widgets, menu commands, and the App Intent hand-off), Spotlight reindexing off the change stream (debounced, fingerprinted), `checkWeatherRisk()`, and `start()` (status sync + watch activation + Spotlight seed + intent hand-off). `RootView` = stage machine (splash → onboarding → main) + environment injection + `.toastContainer()`; `MainView` = the four-tab shell / split view + entry sheet + ongoing chip + deep-link routing.

### App target (`Mygra/`) — thin
`MygraApp` (builds `SessionController` with the app-side seams, registers it with `AppDependencyManager`, hosts `RootView`, owns `BackgroundWeatherRefresh` (BGTaskScheduler) and the 90-minute foreground weather timer; under the test host it uses one process-wide temp-store container). `MygraCommands` (menu bar) drives the same deep-link staging. `Intents/`: `MigraineEntity` (+ query via `@Dependency var session`), the Siri intents (`StartMigraineIntent`, `EndMigraineIntent`, `DaysSinceLastMigraineIntent`, `LogMigraineIntent`, `OpenMygraIntent`, `ViewMigraineIntent`) read/write through the session's use-cases, `MygraShortcuts`, and the app-side seams (`SpotlightIndexer`, `IntentDonor`, `AppStoreReviewRequester`).

### Widgets & Watch
- `MygraWidgetsExtension` links `MygraCore` + `MygraServices` (the old `membershipExceptions` file-sharing is gone). Widget kinds live in `WidgetKind`; the days-since widget reads `SharedMigraineStatus(defaults: AppGroup.defaults)`; the Live Activity renders `MigraineActivityAttributes`. Widgets keep their own asset-catalog colors.
- `Mygra Wrist Watch App` + watch widget link `MygraCore`. `PhoneBridge` is an `@Observable` WatchConnectivity relay over the Core wire types; the phone is the source of truth and the watch is a status mirror + logging interface.
- If a target needs another package module, add it to that target's `packageProductDependencies` in `project.pbxproj` (deterministic `DEC0DE…` IDs).

## Testing
- Swift Testing (`@Suite`, `@Test`, `#expect`). The real suite is in `Packages/Mygra/Tests` (`swift test`, host, simulator-free): `MygraCoreTests` (rules, stats, filter, dates, risk, deep links, status sync, report, use-cases, wire types), `MygraDataTests` (repositories over on-disk temp stores, sample generator), `MygraServicesTests` (weather-risk notifier, sync status, prompts/parsing, weather reading), `MygraFeatureSharedTests` (data/insight models over the preview repositories), `MygraFeatureMigrainesTests` (entry/modify form logic; iOS-only), `MygraCompositionTests` (graph wiring, deep links, intent hand-off, Spotlight reindex).
- **Suites that create SwiftData containers are `.serialized` with a unique on-disk temp store per test** (`MygraStore.makeTemporaryContainer()`) — parallel in-memory containers share a /dev/null SQLite identity and crash the host.
- `MygraTests` (hosted) covers app glue only — **hosted tests must not create SwiftData containers** (the running app already owns one for the same `@Model` classes). Under the test host `MygraApp.isRunningTests` swaps in one process-wide CloudKit-free container on a unique temp store (an in-memory store crashes on the first fetch in the simulator) and skips BGTask registration, donation, and indexing.
- New logic goes into Core (pure) first with tests, then a repository/use-case in Data, then feature behavior over fakes.

## Localization
- Languages: en (source), es, fr-CA, ja via `Mygra/Localizable.xcstrings` (+ `InfoPlist.xcstrings`).
- **Policy for package strings:** SwiftUI's key-based initializers resolve in `Bundle.main`, so translations for package-rendered strings live in the **app target's** catalog, pinned `extractionState: "manual"` + `shouldGenerateSymbol: false`. `STRING_CATALOG_GENERATE_SYMBOLS = NO` on every config block.
- **After adding user-facing strings to package code:** add the key + es/fr-CA/ja translations to `Mygra/Localizable.xcstrings` by hand, then run `python3 Scripts/pin_package_strings.py` (it also reports package literals missing from the catalog). **Don't reword existing keys** — the English literal *is* the key; changing one character orphans three translations.

## Key Patterns & Gotchas
- Health and weather are attached **at log time** for the migraine's window (`MigraineDates.healthWindow`); weather only for same-day starts. Edits re-snapshot both.
- `@ViewBuilder` in package code (the package targets iOS 18); `@ToolbarContentBuilder` is a different type.
- `reorderable()` is iOS 27-only: gate with `#available(iOS 27.0, *)` and keep `onMove` + `EditButton` as the universal path.
- Swift 6 concurrency: non-Sendable values crossing isolation (WCSession reply handlers, BGAppRefreshTask) use `UncheckedSendableBox` (Core); system-framework delegate callbacks extract Sendable values before hopping to `@MainActor`.
- Default-argument isolation: a MainActor-protocol conformer used as a default argument (`= WidgetCenterReloader()`) needs a `nonisolated init() {}`.
- App group `group.com.molargiksoftware.Mygra` and bundle id `com.molargiksoftware.Mygra` are shipping identifiers — don't change them.
- `UNUserNotificationCenter.current()` traps in a process without a bundle: keep it lazy and never call it from `SessionController.init`/`start()` (the app's launch task refreshes the status).
- Verify new API names against the installed SDK's `.swiftinterface` by compiling — never adopt from memory.
