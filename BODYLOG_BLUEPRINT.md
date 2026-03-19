# BodyLog — Product Architecture & Strategy Blueprint

---

## PART 1: INFORMATION ARCHITECTURE

### 1.1 Complete Screen Hierarchy Tree

```
BodyLog App
│
├── Launch Sequence
│   ├── LaunchScreen (static, ~0.5s)
│   └── AppRootView (decides: onboarding vs main app)
│
├── Onboarding (shown once, first launch only)
│   ├── Screen 1 — Unit Selection (kg / lbs)
│   ├── Screen 2 — Goal Weight (scroll picker, skippable)
│   └── Screen 3 — Notification Permission
│
└── MainApp (TabView — 3 tabs)
    │
    ├── Tab 1: Dashboard
    │   ├── WeightEntryCardView (tap → AddWeightSheet)
    │   ├── StreakBadgeView (flame + day count)
    │   ├── WeightChartView (7D / 30D / All Time)
    │   │   └── "All Time" → Paywall (free users)
    │   ├── StatsRowView (current / delta / goal %)
    │   └── RecentEntriesListView (tap → EditWeightSheet)
    │
    ├── Tab 2: Photos
    │   ├── PhotoGridView (2-column, date sorted)
    │   │   ├── Cell tap → PhotoDetailView (fullscreen cover)
    │   │   └── Long press → Compare mode
    │   ├── FAB (+) → PhotoCaptureSheet
    │   │   └── 10th photo → Paywall
    │   ├── CompareButton (header)
    │   └── PhotoCompareView (fullscreen cover — HERO)
    │       ├── DividerSliderView (draggable)
    │       ├── Before/After date selectors
    │       ├── Pose segmented control
    │       └── Share button
    │
    └── Tab 3: Settings
        ├── Unit preference (kg/lbs)
        ├── Goal weight
        ├── Notification time
        ├── Daily entry behavior (update vs new)
        ├── Go Pro / Manage Subscription
        ├── Restore Purchases
        ├── Export CSV → Paywall (free users)
        ├── Delete All Data
        ├── Rate BodyLog
        ├── Privacy Policy / Terms
        └── PaywallSheet (shared modal)
```

### 1.2 Navigation Model

```
Layer 0 │ TabView (persistent, always visible)
        │ Tabs: Dashboard | Photos | Settings
─────────────────────────────────────────────────
Layer 1 │ Sheets (.sheet — partial cover, swipe-dismissible)
        │ AddWeightSheet, EditWeightSheet, PhotoCaptureSheet,
        │ GoalWeightSheet, NotificationPickerSheet, PaywallSheet
─────────────────────────────────────────────────
Layer 2 │ Fullscreen Covers (.fullScreenCover)
        │ PhotoDetailView, PhotoCompareView
─────────────────────────────────────────────────
Layer 3 │ Alerts (system modal)
        │ Delete confirmations, error alerts
─────────────────────────────────────────────────
Layer 4 │ External
        │ SafariView, System Share Sheet, App Store
```

**Rules:**
- No NavigationStack push/pop — app is intentionally flat
- Paywall is a shared singleton sheet controlled by PaywallViewModel
- PhotoCompareView uses fullScreenCover (draggable divider needs full screen)

### 1.3 Data Dependencies Per Screen

| Screen | SwiftData Read | RevenueCat State |
|--------|---------------|-----------------|
| DashboardView | WeightEntry[] (all) | isPro (chart limit) |
| AddWeightSheet | none (write only) | none |
| WeightChartView | WeightEntry[] (filtered) | isPro (All Time gate) |
| StreakBadgeView | WeightEntry[] (dates only) | none |
| PhotosView | PhotoEntry[] (all) | isPro (upload gate) |
| PhotoCompareView | PhotoEntry (2 selected) | isPro (selection gate) |
| SettingsView | UserSettings (singleton) | isPro, entitlements |
| Widget | AppGroup UserDefaults | none |

### 1.4 SwiftData Models

```
WeightEntry
  id: UUID
  date: Date
  weight: Double          // always stored in kg
  note: String?

PhotoEntry
  id: UUID
  date: Date
  fileName: String        // Documents/ directory
  pose: Pose              // .front / .side / .back
  note: String?

UserSettings (singleton)
  unitPreference: Unit    // .kg / .lbs
  goalWeight: Double?     // in kg
  notificationTime: Date?
  notificationEnabled: Bool
  onboardingCompleted: Bool
  dailyEntryBehavior: EntryBehavior  // .addNew / .updateExisting
```

### 1.5 State Management

```
AppViewModel (@Observable, @Environment)
  ├── selectedTab: Tab
  ├── activeSheet: AppSheet?
  ├── isPro: Bool (from EntitlementManager)
  └── openPaywall(trigger:)

EntitlementManager (@Observable, singleton)
  ├── isPro: Bool
  ├── currentOffering: Offering?
  ├── purchase(package:) async
  └── restorePurchases() async

DashboardViewModel (@Observable)
  ├── currentStreak: Int (computed)
  ├── chartData: [ChartPoint] (filtered)
  └── selectedRange: ChartRange

PhotosViewModel (@Observable)
  ├── photoCount: Int (for gate check)
  └── selectedPhotosForCompare: (PhotoEntry, PhotoEntry)?
```

**Reactive chain:**
```
User saves weight → modelContext.insert()
  → @Query auto-updates views
  → Streak recomputed
  → AppGroup UserDefaults updated
  → WidgetCenter.shared.reloadAllTimelines()
```

---

## PART 2: USER FLOWS

### 2.1 First Launch / Onboarding

```
App Launch → Check onboardingCompleted?
  │
  NO → Screen 1: Unit Selection (kg/lbs)
     → Screen 2: Goal Weight (scroll picker, "Skip" available)
     → Screen 3: Notifications ("Allow" → OS prompt / "Maybe Later")
     → Set onboardingCompleted = true
     → Transition to Dashboard
  │
  YES → Dashboard
```

- 3 screens with progress dots
- Clean, minimal design — no stock photos
- Notification screen shows mockup of notification (+30% permission grant rate)

### 2.2 Daily Weight Entry

```
Dashboard → Tap entry card / "+" button
  → AddWeightSheet slides up
    ├── Scroll picker (default: last weight or goal)
    ├── Date (default: today, editable)
    ├── Note (optional)
    └── "Save" → insert/update → dismiss + haptic
```

**Streak logic:**
```
Count consecutive days backward from today.
Grace period: streak doesn't break until end of today.
```

### 2.3 Photo Capture

```
Photos tab → Tap FAB (+)
  → Check: isPro OR photoCount < 10?
    NO → PaywallSheet immediately
    YES → Pose selection (Front/Side/Back)
        → Source: Camera or Library
        → Resize to max 1200px, JPEG 0.85
        → Save to Documents/, insert PhotoEntry
```

### 2.4 Photo Compare (Hero Feature)

```
Entry: "Compare" button or PhotoDetailView

Gate:
  Pro → Select any 2 photos (same pose filtered)
  Free → Auto-select last 2 photos only

PhotoCompareView (fullscreen, black background):
  ┌──────────────────────────────────────┐
  │  BEFORE photo  ┃  AFTER photo       │
  │                ┃                     │
  │  Jan 1, 80kg   ┃  Mar 19, 72.4kg    │
  │         ← drag divider →            │
  └──────────────────────────────────────┘
     [Share]                      [✕]
```

- Divider: DragGesture + mask clipping
- Share: ImageRenderer → system share sheet
- Free users: "Made with BodyLog" watermark on shared image

### 2.5 Paywall Triggers (exactly 3 + 1 inline)

| # | Trigger | Behavior |
|---|---------|----------|
| 1 | "All Time" chart tap | Chart blurs + lock icon + PaywallSheet |
| 2 | 10th photo upload | FAB → PaywallSheet immediately |
| 3 | CSV Export tap | PaywallSheet |
| — | Compare with old photos | Inline banner: "Upgrade to Pro to compare any photos" (no paywall sheet) |

**Inline upsell:** appears max once per session, max 3 times total.

### 2.6 Widget Interaction

```
Small Widget:
  ├── Current weight + unit
  ├── Streak flame + count
  └── Tap → bodylog://dashboard/add-weight
        → Opens Dashboard + AddWeightSheet
```

Data: AppGroup UserDefaults (lastWeight, streak, unit, lastEntryDate)

### 2.7 Notification → App

```
Daily notification at user-set time
  Title: "Time to log your weight"
  Body: "Keep your streak alive — {n} days and counting"

  Tap → Opens Dashboard + AddWeightSheet
  Already logged today → No notification sent
```

---

## PART 3: PASSIVE INCOME & GROWTH

### 3.1 ASO Strategy

**App Name:** BodyLog — Weight Tracker
**Subtitle:** Progress Photos & Body Log
**Keywords:** weight,tracker,body,log,progress,photo,compare,fitness,bmi,fat,loss,gain,gym,before,after

**Screenshots (6):**
1. Photo compare with divider — "See your transformation"
2. Dashboard + chart + streak — "Track every pound, every day"
3. Weight entry — "Log your weight in 2 seconds"
4. Widget on home screen — "Always on your home screen"
5. Photo grid — "Your journey, beautifully stored"
6. Pro features — "Go Pro for less than a coffee"

### 3.2 Retention Mechanics

**Streak:**
- Dashboard: prominent flame icon + day count
- Widget: always visible
- Milestones: Day 7, Day 30 celebrations
- Break warning: 9 PM notification if not logged

**Widget:** Passive daily touchpoint. Prompt to add widget on Day 3.

**Notifications:** Suppress if already logged. Softer tone after 3+ missed days.

### 3.3 Conversion Funnel

```
Install → Onboarding (90%+ completion, no paywall)
  → Day 1 action: log weight (target: 70%)
    → Day 7 retention (target: 35%)
      → Paywall encounter (naturally ~Day 35 for photos)
        → Conversion (target: 4%+ of paywall views)
```

Photo grid counter: "8/10 free photos used" — gentle limit awareness.

### 3.4 Rating Prompt

**Trigger:** After first PhotoCompareView dismiss.
**Conditions:** 5+ weight entries, 7+ days using app, not shown in 60 days.

### 3.5 Pricing Psychology

| Plan | Price | Target User |
|------|-------|-------------|
| Monthly | $2.99/mo | Uncertain, want to try |
| Lifetime | $19.99 one-time | Committed, 3+ weeks usage |

- Lifetime highlighted with "Best Value" badge
- No free trial — free tier IS the trial
- No fake urgency/countdowns

### 3.6 Market Positioning

**vs Progress:** "Progress tracks photos. BodyLog tracks YOU." (combined weight + photo)
**vs HeavySet:** Not a direct competitor (lifting focus)
**vs Libra/Happy Scale:** Weight-only, no photos — photo compare is our moat

**Target persona:** 25-40 year old, gym-going or dieting, wants visual proof of progress.

---

## PART 4: EFFICIENCY DECISIONS

### 4.1 MVP Scope (ship exactly this)

- Onboarding (3 screens)
- Dashboard (weight entry, chart 7D/30D/All, streak, stats)
- Photos (grid, capture, detail)
- Photo Compare with divider (HERO — allocate 2 full days)
- Paywall (3 triggers + inline upsell)
- RevenueCat integration
- Notifications
- Widget (small, read-only)
- Settings (all rows)
- CSV export (Pro)

### 4.2 NOT in MVP

| Feature | Why Not |
|---------|---------|
| HealthKit | Data conflict logic, Apple review scrutiny |
| Social/sharing feed | Requires server, moderation |
| Multiple profiles | No auth = no server = no liability |
| Meal/calorie logging | MyFitnessPal has 80M users |
| Body measurements | 3+ new screens, V2 if demand proven |
| PDF export | PDFKit layout is painful, CSV sufficient |
| Trend predictions/AI | Sparse data → garbage predictions |
| Backend/server | 100% local + RevenueCat + CloudKit |

### 4.3 Technical Shortcuts

1. **Swift Charts** (built-in) — no custom chart library
2. **UIImagePickerController** for camera — works fine, 30min implementation
3. **Photos in Documents folder** — not binary in SwiftData
4. **RevenueCat** handles all IAP complexity — no raw StoreKit2
5. **AppGroup + UserDefaults** for widget — no SwiftData in widget
6. **@Query in views** — no repository abstraction for MVP
7. **System share sheet** — no custom share UI

---

## PART 5: BUILD SEQUENCE

### Phase 1 — Foundation (Week 1)
- Xcode project, SwiftData container, AppGroup entitlement
- Data models: WeightEntry, PhotoEntry, UserSettings
- AppViewModel, EntitlementManager, Config.swift
- LaunchScreen + AppRootView

### Phase 2 — Onboarding + Dashboard (Week 2)
- 3-screen onboarding
- DashboardView layout
- AddWeightSheet with scroll picker
- Swift Charts (7D + 30D, All Time locked)
- Streak computation
- EditWeightSheet + delete

### Phase 3 — Photos + Compare (Week 3)
- PhotosView with 2-column grid
- PhotoCaptureSheet (camera + library)
- Photo compression pipeline (1200px, JPEG 0.85)
- PhotoDetailView
- PhotoCompareView with draggable divider (2 full days)
- Share from compare

### Phase 4 — Monetization + Settings (Week 4)
- PaywallSheet with RevenueCat offerings
- Purchase + restore flows
- All 3 paywall triggers gated
- SettingsView wired
- CSV export
- Notification scheduling

### Phase 5 — Widget + Polish (Week 5)
- Widget extension + AppGroup reads
- Timeline provider + small widget
- Deeplink handling
- Rating prompt
- Empty states
- Haptic feedback
- App icon

### Phase 6 — Submission (Week 6)
- App Store Connect metadata
- Screenshots (6 per device size)
- PrivacyInfo.xcprivacy
- IAP configuration
- Submit for review

---

## FILE STRUCTURE

```
BodyLog/
├── App/
│   ├── BodyLogApp.swift
│   ├── AppViewModel.swift
│   └── Config.swift
├── Models/
│   ├── WeightEntry.swift
│   ├── PhotoEntry.swift
│   └── UserSettings.swift
├── Managers/
│   ├── EntitlementManager.swift
│   └── NotificationManager.swift
├── Features/
│   ├── Onboarding/
│   │   └── OnboardingContainerView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── DashboardViewModel.swift
│   │   ├── AddWeightSheet.swift
│   │   ├── WeightChartView.swift
│   │   └── StreakBadgeView.swift
│   ├── Photos/
│   │   ├── PhotosView.swift
│   │   ├── PhotosViewModel.swift
│   │   ├── PhotoCaptureSheet.swift
│   │   ├── PhotoDetailView.swift
│   │   └── PhotoCompareView.swift
│   ├── Paywall/
│   │   ├── PaywallSheet.swift
│   │   └── PaywallViewModel.swift
│   └── Settings/
│       └── SettingsView.swift
├── Components/
│   ├── WeightPickerView.swift
│   ├── StreakBadgeView.swift
│   └── StatsCardView.swift
├── Extensions/
│   └── Double+Weight.swift
└── Resources/
    └── Assets.xcassets

BodyLogWidget/
├── BodyLogWidget.swift
└── WidgetDataStore.swift
```
