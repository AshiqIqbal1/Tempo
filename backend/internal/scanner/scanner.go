package scanner

import (
	"bytes"
	"image"
	"image/jpeg"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/AshiqIqbal1/Tempo/backend/internal/db"
	"github.com/AshiqIqbal1/Tempo/backend/internal/models"
	"github.com/dhowden/tag"
	"github.com/nfnt/resize"
	taglib "github.com/wtolson/go-taglib"
)

func _GenerateThumbnail(data []byte) ([]byte, error) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	thumb := resize.Resize(256, 256, img, resize.Lanczos3)
	var buf bytes.Buffer
	err = jpeg.Encode(&buf, thumb, &jpeg.Options{Quality: 90})
	return buf.Bytes(), err
}

func getDuration(path string) float64 {
	out, err := exec.Command("ffprobe", "-v", "quiet", "-print_format", "default=noprint_wrappers=1:nokey=1", "-show_entries", "format=duration", path).Output()
	if err != nil {
		return 0
	}
	d, err := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
	if err != nil {
		return 0
	}
	return d
}

func Scan(dir string, database *db.DB) error {
	yearTracks := make(map[int][]int64)
	audiobookFolders := map[string]bool{"Piranesi": true, "ProjectHailMary": true}
	var audiobookTrackIDs []int64

	err := filepath.Walk(dir, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			return nil
		}

		ext := strings.ToLower(filepath.Ext(path))
		validExts := map[string]bool{".mp3": true, ".flac": true, ".m4a": true, ".m4b": true, ".ogg": true, ".opus": true}
		if !validExts[ext] {
			return nil
		}

		// Use taglib for metadata (handles all formats)
		tlFile, err := taglib.Read(path)
		if err != nil {
			// taglib can't read — add with filename + ffprobe duration
			base := filepath.Base(path)
			title := strings.TrimSuffix(base, filepath.Ext(base))
			fallback := models.Track{
				Title:    title,
				Artist:   "Unknown Artist",
				Album:    "Unknown Album",
				Path:     path,
				Duration: getDuration(path),
			}
			id, _ := database.InsertTrack(fallback)
			if id > 0 {
				rel, _ := filepath.Rel(dir, path)
				parts := strings.Split(rel, string(filepath.Separator))
				if len(parts) > 1 && audiobookFolders[parts[0]] {
					audiobookTrackIDs = append(audiobookTrackIDs, id)
				}
			}
			return nil
		}

		newTrack := models.Track{
			Title:    tlFile.Title(),
			Artist:   tlFile.Artist(),
			Album:    tlFile.Album(),
			Path:     path,
			Year:     tlFile.Year(),
			Duration: getDuration(path),
		}
		tlFile.Close()

		// Fallback to filename if metadata is empty
		if newTrack.Title == "" {
			base := filepath.Base(path)
			newTrack.Title = strings.TrimSuffix(base, filepath.Ext(base))
		}
		if newTrack.Artist == "" {
			newTrack.Artist = "Unknown Artist"
		}
		if newTrack.Album == "" {
			newTrack.Album = "Unknown Album"
		}

		id, err := database.InsertTrack(newTrack)
		if err != nil || id == 0 {
			return nil
		}

		// Track year for auto-playlists
		if newTrack.Year > 0 {
			yearTracks[newTrack.Year] = append(yearTracks[newTrack.Year], id)
		}

		// Check if audiobook
		rel, _ := filepath.Rel(dir, path)
		parts := strings.Split(rel, string(filepath.Separator))
		if len(parts) > 1 && audiobookFolders[parts[0]] {
			audiobookTrackIDs = append(audiobookTrackIDs, id)
		}

		// Use dhowden/tag for picture extraction (taglib wrapper doesn't support pictures)
		file, err := os.Open(path)
		if err == nil {
			defer file.Close()
			meta, err := tag.ReadFrom(file)
			if err == nil {
				pic := meta.Picture()
				if pic != nil {
					thumb, err := _GenerateThumbnail(pic.Data)
					if err == nil {
						database.InsertArt(id, pic.Data, thumb)
					}
				}
			}
		}

		return nil
	})

	if err != nil {
		return err
	}

	// Auto-create playlists by 5-year ranges
	ranges := [][3]any{
		{2021, 2026, "2021-2026"},
	}

	for _, r := range ranges {
		lo := r[0].(int)
		hi := r[1].(int)
		name := r[2].(string)
		var ids []int64
		for year, trackIDs := range yearTracks {
			if year >= lo && year <= hi {
				ids = append(ids, trackIDs...)
			}
		}
		if len(ids) == 0 {
			continue
		}
		playlistID, err := database.CreatePlaylist(name)
		if err != nil || playlistID == 0 {
			continue
		}
		for _, trackID := range ids {
			database.AddTrackToPlaylist(playlistID, trackID)
		}
		log.Printf("created playlist %q with %d tracks", name, len(ids))
	}

	// Create Audiobooks playlist
	if len(audiobookTrackIDs) > 0 {
		playlistID, err := database.CreatePlaylist("Audiobooks")
		if err == nil && playlistID > 0 {
			for _, trackID := range audiobookTrackIDs {
				database.AddTrackToPlaylist(playlistID, trackID)
			}
			log.Printf("created playlist %q with %d tracks", "Audiobooks", len(audiobookTrackIDs))
		}
	}

	return nil
}
