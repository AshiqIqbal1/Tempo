# Contributing

Tempo is a personal project but contributions are welcome.

## Setup

### Backend

```bash
cd backend
go mod download
MUSIC_DIR=/path/to/music go run ./cmd/server
```

Requires taglib C library installed:
- macOS: `brew install taglib`
- Ubuntu: `apt install libtagc0-dev`
- Alpine: `apk add taglib-dev`

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

## Code style

- Go: `go fmt`, `go vet`
- Flutter: `flutter analyze`

## Pull requests

1. Fork and branch from `dev`
2. Keep changes focused — one feature or fix per PR
3. Test on a real device if touching audio/playback
4. Backend changes: rebuild Docker image and verify scan works
