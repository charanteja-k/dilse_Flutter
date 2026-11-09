# AGENTS.md — Development Guardrails & Architectural Contract

This document is the **single source of truth and supreme invariant rulebook** for all AI agents, engineers, and automated tools working on the **DilSe** Flutter codebase (`dilse_Flutter`).

Every code addition, refactor, and architectural decision **MUST strictly pass every check** defined in this document. Any pull request or code change violating these rules is considered an architectural regression and must be rejected immediately.

---

## 1. The 3 Core Non-Negotiable Invariants

### 🚨 Invariant 1: Provider & Streams Only (Strictly Zero Singletons)
1. **Zero Global Static Singletons**:
   - ❌ `static final instance = ...` is forbidden.
   - ❌ Global service locators (e.g. `GetIt`, global top-level variables, singleton classes) are forbidden.
   - ❌ Never instantiate long-lived state directly inside a widget.
2. **Context-Driven Injection**:
   - All services, repositories, and ViewModels must be injected into the widget tree using `Provider` / `MultiProvider`.
   - Widgets must access their dependencies strictly via `BuildContext` (`context.read<T>()`, `context.watch<T>()`, `context.select<T, R>()`).
3. **Reactive Streams**:
   - Asynchronous real-time data (audio playback position, track status, network connectivity, user state) must be exposed via `Stream<T>`.
   - Widgets consume streams via `StreamBuilder` or through ViewModels listening to streams with proper cancellation in `dispose()`.

---

### 🚨 Invariant 2: Context-Exposed Design Tokens (Strictly Zero Magic Numbers)
1. **Zero Hardcoded Values**:
   - ❌ Never write hardcoded numbers in UI screens or widgets (e.g. `16.0`, `EdgeInsets.all(12)`, `BorderRadius.circular(8)`, `TextStyle(fontSize: 14)`, `SizedBox(height: 20)`).
   - ❌ Never use raw colors (e.g. `Color(0xFF...)`, `Colors.black`) directly inside view widgets.
2. **The 5 Token Families**:
   Every visual attribute must resolve through the official token system:
   - **`AppSpacing`**: `xxs`, `xs`, `sm`, `md`, `lg`, `xl`, `xxl` (e.g. `context.spacing.md`).
   - **`AppRadius`**: `xs`, `sm`, `md`, `lg`, `card`, `dock`, `full` (e.g. `context.radius.card`).
   - **`AppTypography`**: `displayLarge`, `headlineMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `captionMuted` (e.g. `context.typography.titleLarge`).
   - **`AppSizes`**: `miniPlayerHeight`, `navDockHeight`, `iconSm`, `iconMd`, `iconLg`, `avatarSm`, etc. (e.g. `context.sizes.miniPlayerHeight`).
   - **`AppColors`**: `oledBackground`, `cardDarkSurface`, `floatingDockSurface`, `solidMatteBorder`, `brandRuby`, `successEmerald`, `warningAmber`, `errorCrimson`, `textPrimary`, `textSecondary` (e.g. `context.colors.brandRuby`).
3. **ThemeExtension Delivery**:
   - Tokens must be registered on `ThemeData` as `ThemeExtension`s.
   - Screens must access them via `BuildContext` extensions (`context.spacing`, `context.radius`, `context.typography`, `context.sizes`, `context.colors`).

---

### 🚨 Invariant 3: Strict MVVM (Model - View - ViewModel) Protocol
Every feature must strictly respect the tripartite separation of concerns:

```
┌────────────────────────────────┐
│             MODEL              │   Pure immutable Dart data representations.
│ (data/models/ or feature/model)│   Zero Flutter UI dependencies. Serialization only.
└───────────────▲────────────────┘
                │
                ▼
┌────────────────────────────────┐
│           VIEWMODEL            │   ChangeNotifier / State machine holding business state.
│   (features/*/viewmodels)      │   Zero widget references (no BuildContext, no Widget, no RenderObject).
└───────────────▲────────────────┘
                │
                ▼
┌────────────────────────────────┐
│             VIEW               │   StatelessWidget / StatefulWidget UI code only.
│      (features/*/views)        │   Zero business logic, zero API calls, zero calculation.
└────────────────────────────────┘
```

1. **Models**:
   - Immutable data classes (`@immutable`, final fields, `copyWith`, `fromJson`, `toJson`).
   - Never import `package:flutter/material.dart` in a Model.
2. **ViewModels**:
   - Extend or mix in `ChangeNotifier` (or emit finite state objects).
   - Coordinate repositories/data sources and notify listeners of state transitions (`idle`, `loading`, `success`, `error`).
   - Always cancel open StreamSubscriptions, timers, and controllers in `dispose()`.
   - Never store or accept a `BuildContext` reference.
3. **Views**:
   - Consume ViewModel data via `context.watch<T>()` or `Consumer<T>`.
   - Dispatch user intents via `context.read<T>().someAction()`.
   - Contains only presentation widgets, animations, and token-driven styles.

---

## 2. Directory Structure Protocol

All files must be created within this clean, modular structure:

```
lib/
├── core/
│   ├── theme/
│   │   ├── tokens/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_spacing.dart
│   │   │   ├── app_radius.dart
│   │   │   ├── app_typography.dart
│   │   │   └── app_sizes.dart
│   │   ├── app_theme.dart
│   │   └── theme_extensions.dart
│   ├── extensions/
│   │   └── context_extensions.dart       # context.spacing, context.colors, etc.
│   ├── errors/
│   │   └── failures.dart
│   └── constants/
│       └── api_endpoints.dart
├── data/
│   ├── models/                           # SongModel, PlaylistModel, UserModel
│   ├── datasources/
│   │   ├── remote/                       # CloudflareEdgeApi, FirebaseDatasource
│   │   └── local/                        # StorageDatasource, LocalAudioScanner
│   └── repositories/                     # AudioRepositoryImpl, SearchRepositoryImpl
└── features/
    ├── audio_player/
    │   ├── viewmodels/
    │   └── views/
    ├── home/
    │   ├── viewmodels/
    │   └── views/
    ├── search/
    │   ├── viewmodels/
    │   └── views/
    ├── library/
    │   ├── viewmodels/
    │   └── views/
    └── downloads/
        ├── viewmodels/
        └── views/
```

---

## 3. Platform Standards (Android + Web Compatibility & Java Layer)

1. **Android Layer**:
   - Native layer uses **Java** exclusively (`MainActivity.java`).
   - Gradle build scripts manage Android dependencies.
2. **Web Compatibility**:
   - Web platform (`web/`) is a first-class citizen alongside Android.
   - Code must avoid platform-locked imports without conditional guards (`kIsWeb` or conditional imports).
   - Audio and storage abstraction layers must seamlessly support both Web (HTML5/WebAudio/Web Storage) and Android (ExoPlayer/AudioService/Device storage).
3. **Audio Driver & Background Playback**:
   - Powered by `just_audio` + `audio_service` with web support (`just_audio_web`).
   - Android foreground service declares `android:foregroundServiceType="mediaPlayback"` in `AndroidManifest.xml`.
   - Lockscreen notification supports play, pause, next, previous, and interactive seek scrubbing.
4. **Battery & Android Vitals**:
   - Release audio locks and wake-locks immediately upon pause or exit.
   - Image memory cache capped (`imageCache.maximumSize = 100`) to avoid OOM crashes on budget devices.
5. **Play Store Policy Compliance**:
   - Explicit age validation (13+) in onboarding.
   - In-app Account Deletion & Data Purge flow accessible from Settings.
   - Privacy Policy and Terms of Service explicit acceptance.

---

## 4. Git Version Control & Commit Protocol (Supreme Invariant)

1. **User-Commanded Commits & Pushes Only**:
   - ❌ Never run `git commit` or `git push` autonomously or preemptively.
   - Every commit must be explicitly requested and commanded by the user.
   - The user decides what gets committed, what message is used, and when changes are pushed to GitHub.
2. **Commit Note Standards**:
   - Commit messages must be clear, humanized, structured, and informative (e.g. summarizing what changed, why it changed, and how it was tested).

---

## 5. Agent Pre-Commit Verification Checklist

Before marking any task as complete, every agent MUST verify:
- [ ] **No Singletons**: Grep the new code for `static.*instance` or global state. Are all objects provided via `Provider`?
- [ ] **No Magic Numbers**: Are all paddings, margins, sizes, radii, and fonts resolving through `context.spacing`, `context.radius`, `context.typography`, `context.sizes`, or `context.colors`?
- [ ] **Strict MVVM**: Is all business logic in a `ViewModel`? Does the `View` contain zero calculation or API logic?
- [ ] **Lifecycle Safety**: Are all subscriptions and controllers properly cancelled in `dispose()`?
- [ ] **Static Analysis**: Does `flutter analyze` report zero errors and zero warnings?

