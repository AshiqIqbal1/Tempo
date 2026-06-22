package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"sync"

	"github.com/AshiqIqbal1/Tempo/backend/internal/models"
	"github.com/AshiqIqbal1/Tempo/backend/internal/scanner"
)

var scanMu sync.Mutex
var scanning bool

func (h handler) ListTracks(w http.ResponseWriter, r *http.Request) {
	limit, err := strconv.Atoi(r.URL.Query().Get("limit"))
	if err != nil || limit <= 0 {
		limit = 20
	}

	offset, err := strconv.Atoi(r.URL.Query().Get("offset"))
	if err != nil || offset < 0 {
		offset = 0
	}

	tracks, err := h.db.GetTracks(limit, offset)
	if err != nil {
		http.Error(w, "failed to fetch tracks", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tracks)
}

func (h handler) TriggerScan(w http.ResponseWriter, r *http.Request) {
	scanMu.Lock()
	if scanning {
		scanMu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "already scanning"})
		return
	}
	scanning = true
	scanMu.Unlock()

	go func() {
		defer func() {
			scanMu.Lock()
			scanning = false
			scanMu.Unlock()
		}()
		scanner.Scan(h.musicDir, h.db)
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "scan started"})
}

func (h handler) ListArtists(w http.ResponseWriter, r *http.Request) {
	artists, err := h.db.GetArtists()
	if err != nil {
		http.Error(w, "failed", http.StatusInternalServerError)
		return
	}
	if artists == nil {
		artists = []models.ArtistGroup{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(artists)
}

func (h handler) ListAlbums(w http.ResponseWriter, r *http.Request) {
	albums, err := h.db.GetAlbums()
	if err != nil {
		http.Error(w, "failed", http.StatusInternalServerError)
		return
	}
	if albums == nil {
		albums = []models.AlbumGroup{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(albums)
}

func (h handler) GetArtistTracks(w http.ResponseWriter, r *http.Request) {
	artist := r.URL.Query().Get("name")
	if artist == "" {
		http.Error(w, "missing name", http.StatusBadRequest)
		return
	}
	tracks, err := h.db.GetTracksByArtist(artist)
	if err != nil {
		http.Error(w, "failed", http.StatusInternalServerError)
		return
	}
	if tracks == nil {
		tracks = []models.Track{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tracks)
}

func (h handler) GetAlbumTracks(w http.ResponseWriter, r *http.Request) {
	album := r.URL.Query().Get("album")
	artist := r.URL.Query().Get("artist")
	if album == "" {
		http.Error(w, "missing album", http.StatusBadRequest)
		return
	}
	tracks, err := h.db.GetTracksByAlbum(album, artist)
	if err != nil {
		http.Error(w, "failed", http.StatusInternalServerError)
		return
	}
	if tracks == nil {
		tracks = []models.Track{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tracks)
}

func (h handler) SearchTracks(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("[]"))
		return
	}
	limit, err := strconv.Atoi(r.URL.Query().Get("limit"))
	if err != nil || limit <= 0 {
		limit = 30
	}
	tracks, err := h.db.SearchTracks(q, limit)
	if err != nil {
		http.Error(w, "search failed", http.StatusInternalServerError)
		return
	}
	if tracks == nil {
		tracks = []models.Track{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tracks)
}

func (h handler) ShuffleTracks(w http.ResponseWriter, r *http.Request) {
	limit, err := strconv.Atoi(r.URL.Query().Get("limit"))
	if err != nil || limit <= 0 {
		limit = 100
	}

	tracks, err := h.db.GetRandomTracks(limit)
	if err != nil {
		http.Error(w, "failed to fetch tracks", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tracks)
}

func (h handler) StreamTrack(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid id been passed", http.StatusBadRequest)
		return
	}

	track, err := h.db.GetTrack(id)
	if err != nil {
		http.Error(w, "track not found", http.StatusNotFound)
		return
	}

	http.ServeFile(w, r, track.Path)
}

func (h handler) GetTrackArt(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid id been passed", http.StatusBadRequest)
		return
	}

	data, err := h.db.GetArt(id)
	if err != nil {
		http.Error(w, "track art not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Cache-Control", "max-age=2592000")
	w.Header().Set("Content-Type", "image/jpeg")
	w.Write(data)
}

func (h handler) ListPlaylists(w http.ResponseWriter, r *http.Request) {
	playlists, err := h.db.GetPlaylists()
	if err != nil {
		http.Error(w, "failed to fetch playlists", http.StatusInternalServerError)
		return
	}
	if playlists == nil {
		playlists = []models.Playlist{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(playlists)
}

func (h handler) CreatePlaylist(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Name == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	id, err := h.db.CreatePlaylist(body.Name)
	if err != nil {
		http.Error(w, "failed to create playlist", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int64{"id": id})
}

func (h handler) GetPlaylistTracks(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	limit, err := strconv.Atoi(r.URL.Query().Get("limit"))
	if err != nil || limit <= 0 {
		limit = 20
	}
	offset, err := strconv.Atoi(r.URL.Query().Get("offset"))
	if err != nil || offset < 0 {
		offset = 0
	}
	tracks, err := h.db.GetPlaylistTracks(id, limit, offset)
	if err != nil {
		http.Error(w, "failed to fetch tracks", http.StatusInternalServerError)
		return
	}
	if tracks == nil {
		tracks = []models.Track{}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tracks)
}

func (h handler) AddToPlaylist(w http.ResponseWriter, r *http.Request) {
	playlistID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, "invalid playlist id", http.StatusBadRequest)
		return
	}
	var body struct {
		TrackID int64 `json:"track_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	if err := h.db.AddTrackToPlaylist(playlistID, body.TrackID); err != nil {
		http.Error(w, "failed to add track", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h handler) RemoveFromPlaylist(w http.ResponseWriter, r *http.Request) {
	playlistID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, "invalid playlist id", http.StatusBadRequest)
		return
	}
	trackID, err := strconv.ParseInt(r.PathValue("trackId"), 10, 64)
	if err != nil {
		http.Error(w, "invalid track id", http.StatusBadRequest)
		return
	}
	h.db.RemoveTrackFromPlaylist(playlistID, trackID)
	w.WriteHeader(http.StatusNoContent)
}

func (h handler) DeletePlaylist(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	h.db.DeletePlaylist(id)
	w.WriteHeader(http.StatusNoContent)
}

func (h handler) GetTrackThumbnail(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	data, err := h.db.GetThumbnail(id)
	if err != nil || data == nil {
		http.Error(w, "thumbnail not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Cache-Control", "max-age=2592000")
	w.Header().Set("Content-Type", "image/jpeg")
	w.Write(data)
}
