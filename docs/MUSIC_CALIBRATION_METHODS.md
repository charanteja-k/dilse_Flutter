# DilSe Music Calibration & Recommendation Architecture

This document formalizes the multi-tier recommendation and personal calibration strategies designed to dynamically adapt the **DilSe** audio experience to each user's unique musical DNA.

---

## 1. Executive Summary & Objective

Rather than displaying static, one-size-fits-all trending charts, the DilSe Home Feed and playback queues must adapt to:
1. **User Musical DNA**: Evolving tastes, favored music directors, vocalists, eras, and languages.
2. **Context & Environment**: Time of day, day of week, listening duration, and audio playback hardware (Bluetooth, headphones, phone speaker).
3. **Behavioral Telemetry**: Skip rates (<15s skips), replay frequency, session depth, and volume dynamics.

---

## 2. The 6 Calibration Methods

### Method 1: On-Device Vector Embeddings & Cosine Similarity
- **Compute Layer**: Local Dart execution inside the app (zero server latency, zero API token cost).
- **Core Concept**:
  - Each track is mapped to a discrete multi-attribute feature vector:
    `Track Vector = [weight_artist, weight_genre, weight_tempo, weight_era, weight_sentiment]`
  - As the user plays, hearts, or skips songs, the app maintains an active **User Taste Vector** `U`.
  - When candidate songs are pulled from edge search, local cache, or recommendations, the engine ranks them by **Cosine Similarity**:
    `Similarity(U, T) = (U · T) / (||U|| * ||T||)`
- **Key Advantage**: 100% free, runs offline, sub-5ms computation, privacy-preserving.

---

### Method 2: Graph-Based Collaborative Filtering (Artist Knowledge Graph)
- **Compute Layer**: Local in-memory graph cache + Cloudflare Workers KV lookup.
- **Core Concept**:
  - Music discovery naturally follows collaborative networks between Music Directors, Vocalists, Lyricists, and Companion Artists.
  - An affinity cluster is maintained:
    - *Example*: Listener of **Sid Sriram** -> High edge weight to **Hesham Abdul Wahab**, **Anurag Kulkarni**, and **Gopi Sundar**.
    - *Example*: Listener of **Anirudh** -> High edge weight to **Santhosh Narayanan**, **Thaman S**, and **GV Prakash**.
  - When Track A is played, the traversal engine discovers:
    `Track A -> Primary Composer/Singer -> 1st & 2nd Degree Collaborators -> Candidate Queue`
- **Key Advantage**: Unearths deep-cut tracks and hidden gems rather than recycling standard top-10 chart hits.

---

### Method 3: Sonic Feature Extraction & Harmonic Continuity (BPM & Camelot Wheel)
- **Compute Layer**: Local audio analysis layer (`just_audio` / `flutter_soloud`).
- **Core Concept**:
  - Songs are matched based on their actual acoustic physics:
    1. **BPM / Tempo Matching**: Prevents jarring tempo jumps by clustering playback within compatible tempo bands (e.g. 70–85 BPM for chill acoustic, 120–135 BPM for high-energy mass beats).
    2. **Harmonic Key Matching (Camelot Wheel)**: Ensures transitions between tracks harmonize musically without pitch clashes.
- **Key Advantage**: Creates seamless, professional DJ-grade queue flow.

---

### Method 4: Contextual & Environmental Telemetry
- **Compute Layer**: System sensors and connectivity event streams.
- **Core Concept**:
  - A user’s listening mode transforms based on external physical context:
    1. **Circadian Time Bands**:
       - *06:00 – 10:00*: Soulful acoustics, devotional, morning focus.
       - *12:00 – 16:00*: Midday flow, non-distracting instrumentals, pop singles.
       - *17:00 – 21:00*: High-energy workout, commute anthems, mass tracks.
       - *22:00 – 05:00*: Lo-fi, ambient soundscapes, mellow slow melodies.
    2. **Hardware Route Detection**:
       - **Bluetooth (Car Audio)**: Automatically configures road-trip playlists with large, glanceable controls.
       - **Wired / Wireless Headphones**: Calibrates for immersive stereo and enables high-prominence synced lyrics.
       - **Phone Speaker**: Promotes vocal-forward singles with clear mid-range frequencies.
    3. **Skip-Fatigue Sensor**:
       - Detecting 3 rapid skips (<20 seconds) indicates immediate fatigue with the current style; the system initiates an automatic sub-genre switch.

---

### Method 5: Open Audio Graphs (Last.fm & MusicBrainz Integration)
- **Compute Layer**: Lightweight REST endpoints over Cloudflare Edge.
- **Core Concept**:
  - Leverages 20+ years of global crowdsourced listening patterns via `Last.fm` APIs (`track.getSimilar`, `artist.getSimilar`) and `MusicBrainz` relationships.
  - Enables direct retrieval of authentic co-listening sequences:
    > *"Users who listened to Track X also frequently listened to Track Y within the same session."*
- **Key Advantage**: Eliminates cold-start issues for new songs with crowd-verified transition probabilities.

---

### Method 6: Google AI (Gemini) Thematic Orchestration
- **Compute Layer**: Google Gemini API via edge proxy or Firebase AI Logic.
- **Core Concept**:
  - Handles nuanced semantic and natural language intent that pure mathematical vectors miss.
  - **Thematic Archetypes**: Converts recent history into stylized editorial titles (e.g. *"Monsoon Melancholy"*, *"Midnight Highway"*, *"Neon Coding Flow"*).
  - **Conversational Playlist Construction**: Translates prompts (e.g. *"Songs like Inkem Inkem for a rainy bike ride"*) into optimized search seeds for JioSaavn and YouTube Music graphs.

---

## 3. Comparison Matrix

| Method | Latency | Compute / Cost | Offline Ready | Primary Strength |
| :--- | :--- | :--- | :--- | :--- |
| **1. Local Vector Similarity** | < 5 ms | $0 (Local Dart) | Yes | Instant taste alignment |
| **2. Artist Knowledge Graph** | < 50 ms | $0 (In-Memory / KV) | Yes | Discovery of related artists & gems |
| **3. Sonic BPM / Harmonics** | Real-time | $0 (Local Audio) | Yes | Smooth transitions & musical flow |
| **4. Contextual Telemetry** | Instant | $0 (Device Sensors) | Yes | Situation-aware playlists (Car/Bed/Gym) |
| **5. Last.fm / Open Graph** | ~150 ms | Free API tier | No | Millions of real listening patterns |
| **6. Google Gemini AI** | ~400 ms | Free/Token-based | No | Semantic vibe naming & natural prompt queues |

---

## 4. Architectural Roadmap for DilSe

1. **Phase 1 (On-Device MVP - Zero Cost)**:
   - Combine **Method 1 (Local Vector Profiling)** + **Method 4 (Circadian & Hardware Telemetry)**.
   - Populate Home Feed shelves directly using the user's real listening history and liked artists from `StorageDatasource`.
2. **Phase 2 (Cloudflare Edge Audio Graph)**:
   - Implement **Method 2 (Artist Knowledge Graph)** and integrate **Method 5 (Last.fm Similar Tracks)** via Cloudflare Workers.
3. **Phase 3 (Google Gemini & Firebase Cloud Sync)**:
   - Synchronize taste vectors across devices via Cloud Firestore.
   - Introduce conversational queue building and dynamic aesthetic shelf labeling via Google Gemini.

