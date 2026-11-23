# DilSe Personalized Queue Calibration Architecture

This document preserves the architectural specifications, algorithmic calibration models, testing benchmarks, and UI/UX contracts for DilSe's 50-track personalized queue engine.

---

## 1. Problem Statement & Motivation

Prior to calibration, raw algorithmic radio queues (such as Google InnerTube/YouTube Music Radio or JioSaavn radio) exhibited two fundamental failure modes:

1. **Language & Cultural Drift (Raw YouTube Radio)**:
   - When seeded with a Telugu melodic hit (e.g., *Chuttamalle* by Anirudh Ravichander), raw radio queues frequently drifted into unrelated Hindi, Tamil, or Punjabi chart toppers (*Chaleya*, *Chammak Challo*, *Naal Nachna*) simply based on global co-listening volume, disregarding the listener's individual cultural profile.
2. **Duplicate & Shallow Recommendations (Raw JioSaavn)**:
   - When querying songs on catalog search or standard station APIs, results often collapsed into 10 duplicate remixes, festival cuts, and alternate acoustic masters of the exact same title.
3. **Absence of User Familiarity Pacing**:
   - Continuous streams of unfamiliar music cause listener fatigue ("skip storms").
   - Conversely, continuous loops of already-liked songs cause boredom.

---

## 2. User Listening DNA Profile (Empirical Benchmark)

Analysis of the 723-track listener history (`Liked_Songs.csv`) established the ground-truth listening DNA:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        USER LISTENING DNA                              │
├────────────────────────────────────────────────────────────────────────┤
│ Total History:   723 Verified Liked Tracks                             │
│ Primary Genres:  Telugu Pop (54%), Tollywood (53%), Tamil Pop (39%),   │
│                  Bollywood (28%), Hindi Pop (23%), Devotional (20%).   │
│ Top Artists:     Karthik (38), Sid Sriram (29), A.R. Rahman (26),      │
│                  Devi Sri Prasad (26), Shreya Ghoshal (24),            │
│                  S. P. Balasubrahmanyam (23), Anirudh Ravichander (21),│
│                  Shankar Mahadevan (16), Anurag Kulkarni (16),         │
│                  KK (12), K. S. Chithra (14), Chinmayi (9).            │
│ Western Pop:     Ed Sheeran (5), Imagine Dragons (4), The Weeknd (3).  │
│ Acoustic DNA:    Danceability: 0.67 | Energy: 0.66 | Valence: 0.57     │
│                  (Preference: High-melody, upbeat vocal tracks)        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. The 50-Song Queue Calibration Engine

Instead of naive truncation, DilSe uses a progressive **50-Song Two-Stage Re-Ranking Pipeline**.

### Two-Stage Pipeline

```
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 1: Candidate Generation (Cloudflare Edge Worker)           │
│ /ytm/radio?v={videoId}&limit=50  +  /jio/search?q={query}&limit=50│
└─────────────────────────────────┬────────────────────────────────┘
                                  │ (~50-80 raw candidate pool)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 2: Personalized Taste Scoring & Calibration                │
│ • Artist Affinity Weight: Score = (ArtistLikes / MaxLikes) * 0.45│
│ • Library Familiarity Boost: +0.20 if song exists in liked songs │
│ • Cross-Language Bridge Check: Shared composer/singer continuity │
│ • Deduplication & Title Normalization                            │
└─────────────────────────────────┬────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 3: Paced Interleaving (3:2 Rhythmic Distribution)          │
│ • Blend Languages (Default): 56% Discovery / 44% Familiar Anchors│
│ • Discover Mode: 70% Discovery / 30% Familiar Anchors            │
│ • Familiar Mode: 40% Discovery / 60% Familiar Anchors            │
│ • Single Language Mode: Strict linguistic quarantine             │
└──────────────────────────────────────────────────────────────────┘
```

### The 4 Calibration Modes

| Mode | Ratio (50 Tracks) | Behavior & Rules |
|---|---|---|
| **🌐 Blend Languages** *(Default)* | **~28 Discovery (56%) : ~22 Familiar (44%)** | Allows natural cross-language bridges (Telugu ↔ Tamil ↔ Hindi) when connected by shared favorite composers (Anirudh, Rahman) or singers (Sid Sriram, Arijit, Shreya Ghoshal). |
| **🚀 Discover** | **35 Discovery (70%) : 15 Familiar (30%)** | Exploration-first. Paces 7 fresh discoveries followed by 3 familiar anchors to prevent listener fatigue. |
| **☕ Familiar** | **20 Discovery (40%) : 30 Familiar (60%)** | Comfort-first. Prioritizes tracks from your top artists and liked library, sprinkling 4 fresh discoveries per 10 songs. |
| **🔒 Single Language** | **~30 Discovery : ~20 Familiar** | Strict linguistic quarantine. Enforces same-language continuity only (e.g. zero Hindi/Tamil crossover during a Telugu session). |

---

## 4. Empirical Test Results Across Languages

### Telugu Seed: *Chuttamalle* (Anirudh Ravichander — Devara)
* **Raw YTM Radio Issues**: *Chaleya* (#1 - Hindi), *Aasa Kooda* (#2 - Tamil Indie), *Chammak Challo* (#9 - Hindi).
* **Calibrated Output (Blend Languages)**:
  1. *Aasa Kooda* — Sai Abhyankkar `[Discovery]`
  2. *Othaiyadi Pathayila* — Dhibu Ninan Thomas `[Discovery]`
  3. *KALYANI (Remix)* — ARJN `[Discovery]`
  4. *Chaleya* — Arijit Singh / Anirudh `[Top Artist / Bridge]`
  5. *Endhayya Saami* — Ajay-Atul `[Similar Vibe]`
  6. *Unakkul Naane* — Pritt `[Discovery]`
  7. *Udi Udi* — Aneesh `[Discovery]`
  8. *Peelings* — Shankarr Babu `[Discovery]`
  9. *Maate Vinadhuga* — Sid Sriram `[Top Artist - 29 Likes]`
  10. *Samayama* — Anurag Kulkarni `[Top Artist - 16 Likes]`
  *(Tracks 20–35 bridge into Hukum, Yenti Yenti, Dheere Dheere, Inthandham, and Daavudi).*

### Hindi Seed: *Tum Hi Ho* (Arijit Singh — Aashiqui 2)
* **Calibrated Output**: Paces soulful romantic discoveries (*Sunn Raha Hai*, *Jeene Laga Hoon*, *Saiyaara*) with highest-affinity anchors (*Janam Janam*, *Dil Ibaadat* by KK, *Khairiyat*, *Sanam Re*, *Agar Tum Saath Ho*).

### English Seed: *Starboy* (The Weeknd)
* **Calibrated Output**: Balances upbeat synth-pop discoveries (*All The Stars*, *STAY*, *Attention*) with library favorites (*Blinding Lights*, *Heat Waves*, *Shape of You*, *Believer*).

---

## 5. Queue Screen UI/UX Specification

Compliant with [AGENTS.md](file:///Users/charanteja/Desktop/College_Related/my_projects/dilse_Flutter/AGENTS.md) Invariants:
* **Invariant 1**: Injected via `Provider` & `QueueManager`, zero singletons.
* **Invariant 2**: Design tokens only (`context.spacing`, `context.colors`, `context.radius`, `context.typography`, `context.sizes`).
* **Invariant 3**: Strict MVVM (View contains presentation only).
* **Invariant 4**: Pure Monochrome Black & White theme (OLED `#000000`, card `#121214`, border `#222226`, text `#FFFFFF`). Album artwork is the sole element permitted color.

### Key UI Components
1. **Header**:
   - `Playing Queue` with pill badge showing active track count (`50`).
   - Clean standard subtitle: `"Playing from Radio"`.
   - Header action buttons: `playlist_add` (Save queue to playlist) and `close` (Dismiss sheet).
2. **Pinned Now Playing Master Card**:
   - Elevated matte surface card (`#121214`, border `#222226`).
   - High-res artwork with rounded border.
   - Text badge: `"NOW PLAYING • 320 KBPS"` (clean text, no glowing blip).
   - Track title, artist, and live monochrome animated equalizer bars.
3. **Queue Mode Tuning Dock**:
   - Header with `"Queue Mode"` and `"Clear Queue"` text action.
   - Horizontally scrollable pills:
     - `[ 🌐 Blend Languages ]` *(Active default)*
     - `[ 🚀 Discover ]`
     - `[ ☕ Familiar ]`
     - `[ 🔒 Single Language ]`
4. **Up Next Section**:
   - Subtitle: `"UP NEXT • 50 TRACKS • 3 HR 12 MIN"`.
   - Continuous Autoplay (Infinite Flow) is built-in and always active (no redundant switch).
5. **Interactive Track Items**:
   - Two-digit mono index numbers (`01`, `02`, ..., `50`).
   - Standard monochrome metadata badges: `Top Artist`, `In Library`, `Discovery`, `Similar Vibe`.
   - Swipe left to dismiss (`DismissDirection.endToStart`).
   - Drag handle `☰` for reordering (`ReorderableListView`).

