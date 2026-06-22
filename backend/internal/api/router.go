package api

import (
	"net/http"

	"github.com/AshiqIqbal1/Tempo/backend/internal/db"
)

type handler struct {
	db       *db.DB
	musicDir string
}

func NewRouter(database *db.DB, musicDir string) http.Handler {
	mux := http.NewServeMux()
	h := handler{db: database, musicDir: musicDir}
	mux.HandleFunc("GET /tracks", h.ListTracks)
	mux.HandleFunc("GET /artists", h.ListArtists)
	mux.HandleFunc("GET /artists/tracks", h.GetArtistTracks)
	mux.HandleFunc("GET /albums", h.ListAlbums)
	mux.HandleFunc("GET /albums/tracks", h.GetAlbumTracks)
	mux.HandleFunc("POST /scan", h.TriggerScan)
	mux.HandleFunc("GET /tracks/search", h.SearchTracks)
	mux.HandleFunc("GET /tracks/shuffle", h.ShuffleTracks)
	mux.HandleFunc("GET /tracks/{id}/stream", h.StreamTrack)
	mux.HandleFunc("GET /tracks/{id}/art", h.GetTrackArt)
	mux.HandleFunc("GET /tracks/{id}/art/thumbnail", h.GetTrackThumbnail)
	mux.HandleFunc("GET /playlists", h.ListPlaylists)
	mux.HandleFunc("POST /playlists", h.CreatePlaylist)
	mux.HandleFunc("GET /playlists/{id}/tracks", h.GetPlaylistTracks)
	mux.HandleFunc("POST /playlists/{id}/tracks", h.AddToPlaylist)
	mux.HandleFunc("DELETE /playlists/{id}/tracks/{trackId}", h.RemoveFromPlaylist)
	mux.HandleFunc("DELETE /playlists/{id}", h.DeletePlaylist)
	return mux
}
