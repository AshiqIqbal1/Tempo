package models

type Track struct {
	ID       int64   `json:"id"`
	Title    string  `json:"title"`
	Artist   string  `json:"artist"`
	Album    string  `json:"album"`
	Path     string  `json:"path"`
	Year     int     `json:"year"`
	Duration float64 `json:"duration"`
}

type ArtistGroup struct {
	Artist     string `json:"artist"`
	TrackCount int    `json:"track_count"`
}

type AlbumGroup struct {
	Album      string `json:"album"`
	Artist     string `json:"artist"`
	TrackCount int    `json:"track_count"`
	Year       int    `json:"year"`
}

type Playlist struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	TrackCount int    `json:"track_count"`
}
