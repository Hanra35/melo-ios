# Melo — iOS Native App

Application iOS native pour Melo Music, compilable via GitHub Actions et installable avec **TrollStore**.

## Structure du projet

```
MeloApp/
├── MeloApp.xcodeproj/
│   └── project.pbxproj
├── MeloApp/
│   ├── MeloApp.swift           ← Entry point
│   ├── Info.plist              ← Permissions + background audio
│   ├── Models/
│   │   └── Models.swift        ← Track, Playlist, Album, Artist, LRC
│   ├── Services/
│   │   ├── B2Service.swift     ← API Backblaze B2 (stream, upload, delete, metadata)
│   │   ├── PlayerService.swift ← AVPlayer + Now Playing + LRC sync
│   │   ├── LibraryStore.swift  ← State management + sync B2
│   │   └── LyricsService.swift ← Auto-fetch via lrclib.net
│   ├── Views/
│   │   ├── ContentView.swift   ← Tab bar + mini player + splash
│   │   ├── HomeView.swift      ← Accueil / Titres / Albums
│   │   ├── PlayerView.swift    ← Full screen player + paroles LRC + queue
│   │   ├── PlaylistsArtistsViews.swift
│   │   └── ImportStorageViews.swift
│   └── Extensions/
│       └── DesignSystem.swift  ← Colors, TrackArtView, Haptics
└── .github/workflows/build.yml ← GitHub Actions → IPA TrollStore
```

## Configuration

### 1. URL de l'API Vercel
Ouvrir `MeloApp/Services/B2Service.swift` et changer :
```swift
let kAPIBase = "https://TON-APP.vercel.app/api/api"
```

### 2. Compiler avec GitHub Actions

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/TON_USERNAME/melo-ios.git
git push -u origin main
```

→ GitHub Actions va automatiquement builder et créer un artifact `Melo-IPA`.

### 3. Créer une release avec l'IPA

```bash
git tag v1.0.0
git push --tags
```

### 4. Installer via TrollStore
1. Télécharger `Melo.ipa` depuis les releases GitHub
2. Ouvrir TrollStore sur iPhone
3. Appuyer sur **+** → sélectionner le `.ipa`
4. Appuyer sur **Install**

## Fonctionnalités

- 🎵 Streaming direct depuis Backblaze B2
- 📤 Upload de fichiers audio (MP3, FLAC, WAV, AAC, M4A)
- 📚 Bibliothèque : titres, playlists, albums, artistes
- 🎤 Paroles synchronisées (LRC) — fetch auto via lrclib.net
- 🔀 Shuffle, répétition, queue réorderable
- 📡 Now Playing + contrôles en arrière-plan
- 💾 Cache local + sync B2
- 🌙 Thème sombre (design identique à l'app web)

## Compatibilité
- iOS 15.0+
- iPhone uniquement
- TrollStore requis (pas de signature Apple)

## Notes techniques
- **SwiftUI** + **AVFoundation** pour la lecture audio
- **@MainActor** pour tout le state partagé
- Pas de dépendances externes (zéro Swift Package)
- Compatible Xcode 15+
