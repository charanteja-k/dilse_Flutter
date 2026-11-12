# DILSE MUSIC (PLAY STORE EDITION) — MASTER SYSTEM GOVERNANCE & ARCHITECTURAL DIRECTIVE

You are working on the Google Play Store edition of DilSe Music (`com.charant.dilse`).
This repository houses the brand-new, tactile, production Flutter UI targeting Google Play Store release via Android App Bundle (`.aab`), powered by the sovereign DilSe headless audio engine and Cloudflare Edge Worker.

---

## 1. COLLABORATION & REPO SYNCHRONIZATION RULES

- **Charan's Upstream Commits:** Charan is developing the core headless engine and initial skeletal structures on his local machine and pushing to this repository.
- **Merge & Sync Invariant:** Always preserve Charan's commit integrity. Never overwrite or rebase away upstream commit history.
- **Rule #10 (Remote Git Push Governance):** NEVER run `git push` automatically. Always work locally, write granular commits (`git commit`), and only run `git push` when the user explicitly commands you to push to remote.

---

## 2. THE PRIME DIRECTIVE: 4-ZONE SEPARATION

```text
Zone A: Presentation (Full Authority) ── New screens, widgets, buttons, animations, haptics.
Zone B: Application Services (Controlled) ── Public interfaces (MusicService, PreferencesService).
Zone C: Core Engine (ARCHITECTURALLY IMMUTABLE) ── _playerA/_playerB dual-deck crossfade, ExoPlayer audio sessions, fallback cascades.
Zone D: Infrastructure (Strictly Protected) ── Cloudflare Edge Worker (14 endpoints), JioSaavn CDN, YouTube InnerTube.
```

### Absolute Rules:
1. NEVER rewrite `MusicService`, `_playerA`, `_playerB`, or dual-deck crossfade math to make UI code easier. The UI *consumes* the engine; the UI *never becomes* the engine.
2. NEVER introduce secondary playback clocks, duplicate queue arrays, or direct player backdoors into widgets.
3. NEVER proxy audio through custom private servers. All audio resolves client-side from JioSaavn 320k or YouTube residential streams.
4. NEVER remove or bypass `CanonicalSongDedup`. It is the single source of truth for song identification.

---

## 3. GOOGLE PLAY STORE (.AAB) COMPLIANCE STANDARDS

1. **Packaging:** Target format is Android App Bundle (`.aab` via `flutter build appbundle --release`).
2. **Permissions:**
   - DO NOT declare `REQUEST_INSTALL_PACKAGES` or include raw APK download/OTA self-updaters.
   - Use Google Play In-App Updates API for update delivery.
   - Retain `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for Android 14+ background audio.
3. **Target SDK:** Must target API 34 or 35. Core library desugaring and Java 17 enabled.
4. **ProGuard / R8:** Keep rules must be maintained in `android/app/proguard-rules.pro` for Kotlin Coroutines, Continuation, Unit, and Pigeon JNI bindings to prevent release black-screen crashes.

---

## 4. DESIGN STANDARD (RULE #9: MATTE OBSIDIAN, ZERO NEONS)

1. Strictly minimalist, matte, solid color visual standard.
2. ZERO bright neons, fluorescent lighting, rainbow accents, or loud linear/radial gradients.
3. Palette:
   - Deep Obsidian container backgrounds: `#161618` / `#18181B`
   - Crisp matte borders: `#2E2E32`
   - Solid Emerald for success/downloads/bitrate: `#1DB954`
   - Solid Ruby for brand/now playing/favorites: `#FA2D48`
   - Solid Amber for warnings/offline: `#F59E0B`
   - Solid Crimson for deletions/errors: `#EF4444`
   - Solid Slate for typography & subtitles: `#94A3B8` / `#64748B`

---

## 5. CLOUDFLARE EDGE WORKER INTERFACE (DO NOT ALTER)

Base URL: `https://dilse-edge-stream.charanteja-kondakalla030206.workers.dev`
- Search: `GET /jio/search?q=&limit=&page=`
- Autocomplete: `GET /jio/suggestions?q=&limit=`
- Single Resolver: `GET /jio?title=&artist=`
- Autochain Recommendations: `GET /jio/recommendations?q=&language=&limit=`
- Regional Trending: `GET /jio/trending?lang=`
- Regional Top Charts: `GET /jio/charts?lang=`
- Featured Albums: `GET /jio/featured_albums?lang=&limit=`
- Album Songs: `GET /jio/album?id=`
- Lyrics (LRCLIB + YTM + Jio): `GET /lyrics?title=&artist=&lang=&duration=&videoId=`
- Neural Automix Radio: `GET /ytm/radio?v=&limit=`
- User Cloud Backup: `GET /user/sync?userId=` and `POST /user/sync`

---

## 6. VERIFICATION QUALITY GATE (MANDATORY ON EVERY TASK)

Before claiming any task or feature is complete:
1. `dart format lib/ test/` (must yield 0 changed files)
2. `flutter analyze lib/` (must yield 0 errors, 0 warnings, 0 infos)
3. `flutter test` (all unit and widget tests must pass 100%)
4. Clean transient platform files: `git checkout -- linux/ macos/ windows/`

