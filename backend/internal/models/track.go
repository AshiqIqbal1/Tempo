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

type Playlist struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	TrackCount int    `json:"track_count"`
}
