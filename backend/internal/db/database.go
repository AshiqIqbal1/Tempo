package db

import (
	"database/sql"

	"github.com/AshiqIqbal1/Tempo/backend/internal/models"
	_ "modernc.org/sqlite"
)

type DB struct {
	conn *sql.DB
}

func New(path string) (*DB, error) {

	db, err := sql.Open("sqlite", path)

	if err != nil {
		return nil, err
	}

	query := `
		CREATE TABLE IF NOT EXISTS tracks (
			id     INTEGER PRIMARY KEY AUTOINCREMENT,
			title  TEXT NOT NULL,
			artist TEXT NOT NULL,
			album  TEXT NOT NULL,
			path     TEXT NOT NULL UNIQUE,
			year     INTEGER NOT NULL DEFAULT 0,
			duration REAL NOT NULL DEFAULT 0
		)
	`

	_, err = db.Exec(query)
	if err != nil {
		return nil, err
	}

	_, err = db.Exec(
		`
			CREATE TABLE IF NOT EXISTS art 
			(
				track_id  INTEGER PRIMARY KEY,
				data      BLOB,
				thumbnail BLOB
			)
		`,
	)
	if err != nil {
		return nil, err
	}

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS playlists (
			id   INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL UNIQUE
		)
	`)
	if err != nil {
		return nil, err
	}

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS playlist_tracks (
			playlist_id INTEGER NOT NULL,
			track_id    INTEGER NOT NULL,
			position    INTEGER NOT NULL,
			PRIMARY KEY (playlist_id, track_id)
		)
	`)
	if err != nil {
		return nil, err
	}

	db.Exec("CREATE INDEX IF NOT EXISTS idx_tracks_title ON tracks(title COLLATE NOCASE)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artist COLLATE NOCASE)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(album COLLATE NOCASE)")

	return &DB{conn: db}, nil
}

func (db *DB) InsertTrack(track models.Track) (int64, error) {
	query := `
		INSERT OR IGNORE INTO tracks (title, artist, album, path, year, duration)
		VALUES (?, ?, ?, ?, ?, ?)
	`

	result, err := db.conn.Exec(query, track.Title, track.Artist, track.Album, track.Path, track.Year, track.Duration)
	if err != nil {
		return 0, err
	}
	return result.LastInsertId()
}

func (db *DB) GetTracks(limit int, offset int) ([]models.Track, error) {
	query := `
		SELECT id, title, artist, album, path, year, duration
		FROM tracks
		ORDER BY id
		LIMIT ? OFFSET ?
	`

	rows, err := db.conn.Query(query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tracks []models.Track
	for rows.Next() {
		var track models.Track

		err = rows.Scan(&track.ID, &track.Title, &track.Artist, &track.Album, &track.Path, &track.Year, &track.Duration)
		if err != nil {
			return nil, err
		}

		tracks = append(tracks, track)
	}

	return tracks, nil
}

func (db *DB) GetRandomTracks(limit int) ([]models.Track, error) {
	query := `
		SELECT id, title, artist, album, path, year, duration
		FROM tracks
		ORDER BY RANDOM()
		LIMIT ?
	`

	rows, err := db.conn.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tracks []models.Track
	for rows.Next() {
		var track models.Track
		err = rows.Scan(&track.ID, &track.Title, &track.Artist, &track.Album, &track.Path, &track.Year, &track.Duration)
		if err != nil {
			return nil, err
		}
		tracks = append(tracks, track)
	}

	return tracks, nil
}

func (db *DB) SearchTracks(query string, limit int) ([]models.Track, error) {
	q := "%" + query + "%"
	prefix := query + "%"
	rows, err := db.conn.Query(`
		SELECT id, title, artist, album, path, year, duration
		FROM tracks
		WHERE title LIKE ? OR artist LIKE ? OR album LIKE ?
		ORDER BY
			CASE WHEN title LIKE ? THEN 0
			     WHEN artist LIKE ? THEN 1
			     ELSE 2 END,
			title
		LIMIT ?
	`, q, q, q, prefix, prefix, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tracks []models.Track
	for rows.Next() {
		var track models.Track
		if err := rows.Scan(&track.ID, &track.Title, &track.Artist, &track.Album, &track.Path, &track.Year, &track.Duration); err != nil {
			return nil, err
		}
		tracks = append(tracks, track)
	}
	return tracks, nil
}

func (db *DB) GetTrack(id int64) (*models.Track, error) {
	query := `
		SELECT id, title, artist, album, path, year, duration
		FROM tracks
		WHERE id = ?
	`
	var track models.Track
	err := db.conn.QueryRow(query, id).Scan(&track.ID, &track.Title, &track.Artist, &track.Album, &track.Path, &track.Year, &track.Duration)
	if err != nil {
		return nil, err
	}

	return &track, nil
}

func (db *DB) InsertArt(trackID int64, art []byte, thumbnail []byte) error {
	query := `
		INSERT OR IGNORE INTO art (track_id, data, thumbnail)
		VALUES (?, ?, ?)
	`

	_, err := db.conn.Exec(query, trackID, art, thumbnail)
	return err
}

func (db *DB) GetArt(trackID int64) ([]byte, error) {
	query := `
		SELECT data
		FROM art
		WHERE track_id = ?
	`
	var data []byte
	err := db.conn.QueryRow(query, trackID).Scan(&data)
	if err != nil {
		return nil, err
	}

	return data, nil
}

func (db *DB) GetThumbnail(trackID int64) ([]byte, error) {
	query := `
		SELECT thumbnail
		FROM art
		WHERE track_id = ?
	`
	var thumbnail []byte
	err := db.conn.QueryRow(query, trackID).Scan(&thumbnail)
	if err != nil {
		return nil, err
	}

	return thumbnail, nil
}

func (db *DB) CreatePlaylist(name string) (int64, error) {
	result, err := db.conn.Exec("INSERT OR IGNORE INTO playlists (name) VALUES (?)", name)
	if err != nil {
		return 0, err
	}
	return result.LastInsertId()
}

func (db *DB) GetPlaylists() ([]models.Playlist, error) {
	rows, err := db.conn.Query(`
		SELECT p.id, p.name, COUNT(pt.track_id) as track_count
		FROM playlists p
		LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
		GROUP BY p.id
		ORDER BY p.name
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var playlists []models.Playlist
	for rows.Next() {
		var p models.Playlist
		if err := rows.Scan(&p.ID, &p.Name, &p.TrackCount); err != nil {
			return nil, err
		}
		playlists = append(playlists, p)
	}
	return playlists, nil
}

func (db *DB) GetPlaylistTracks(playlistID int64, limit, offset int) ([]models.Track, error) {
	rows, err := db.conn.Query(`
		SELECT t.id, t.title, t.artist, t.album, t.path, t.year, t.duration
		FROM tracks t
		JOIN playlist_tracks pt ON t.id = pt.track_id
		WHERE pt.playlist_id = ?
		ORDER BY pt.position
		LIMIT ? OFFSET ?
	`, playlistID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tracks []models.Track
	for rows.Next() {
		var t models.Track
		if err := rows.Scan(&t.ID, &t.Title, &t.Artist, &t.Album, &t.Path, &t.Year, &t.Duration); err != nil {
			return nil, err
		}
		tracks = append(tracks, t)
	}
	return tracks, nil
}

func (db *DB) AddTrackToPlaylist(playlistID, trackID int64) error {
	var maxPos int
	db.conn.QueryRow("SELECT COALESCE(MAX(position), -1) FROM playlist_tracks WHERE playlist_id = ?", playlistID).Scan(&maxPos)
	_, err := db.conn.Exec("INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, position) VALUES (?, ?, ?)",
		playlistID, trackID, maxPos+1)
	return err
}

func (db *DB) RemoveTrackFromPlaylist(playlistID, trackID int64) error {
	_, err := db.conn.Exec("DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?", playlistID, trackID)
	return err
}

func (db *DB) DeletePlaylist(playlistID int64) error {
	db.conn.Exec("DELETE FROM playlist_tracks WHERE playlist_id = ?", playlistID)
	_, err := db.conn.Exec("DELETE FROM playlists WHERE id = ?", playlistID)
	return err
}

func (db *DB) GetArtists() ([]models.ArtistGroup, error) {
	rows, err := db.conn.Query(`
		SELECT
			CASE WHEN INSTR(artist, '/') > 0
				THEN TRIM(SUBSTR(artist, 1, INSTR(artist, '/') - 1))
				ELSE artist
			END as primary_artist,
			COUNT(*) as track_count
		FROM tracks
		GROUP BY primary_artist
		HAVING track_count >= 5
		ORDER BY primary_artist
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var artists []models.ArtistGroup
	for rows.Next() {
		var a models.ArtistGroup
		if err := rows.Scan(&a.Artist, &a.TrackCount); err != nil {
			return nil, err
		}
		artists = append(artists, a)
	}
	return artists, nil
}

func (db *DB) GetAlbums() ([]models.AlbumGroup, error) {
	rows, err := db.conn.Query(`
		SELECT album, artist, COUNT(*) as track_count, MAX(year) as year, MIN(id) as first_track_id
		FROM tracks
		GROUP BY album, artist
		ORDER BY album
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var albums []models.AlbumGroup
	for rows.Next() {
		var a models.AlbumGroup
		if err := rows.Scan(&a.Album, &a.Artist, &a.TrackCount, &a.Year, &a.FirstTrackID); err != nil {
			return nil, err
		}
		albums = append(albums, a)
	}
	return albums, nil
}

func (db *DB) GetTracksByArtist(artist string) ([]models.Track, error) {
	rows, err := db.conn.Query(`
		SELECT id, title, artist, album, path, year, duration
		FROM tracks WHERE artist = ? OR artist LIKE ? ORDER BY album, title
	`, artist, artist+"/%")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tracks []models.Track
	for rows.Next() {
		var t models.Track
		if err := rows.Scan(&t.ID, &t.Title, &t.Artist, &t.Album, &t.Path, &t.Year, &t.Duration); err != nil {
			return nil, err
		}
		tracks = append(tracks, t)
	}
	return tracks, nil
}

func (db *DB) GetTracksByAlbum(album, artist string) ([]models.Track, error) {
	rows, err := db.conn.Query(`
		SELECT id, title, artist, album, path, year, duration
		FROM tracks WHERE album = ? AND artist = ? ORDER BY id
	`, album, artist)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tracks []models.Track
	for rows.Next() {
		var t models.Track
		if err := rows.Scan(&t.ID, &t.Title, &t.Artist, &t.Album, &t.Path, &t.Year, &t.Duration); err != nil {
			return nil, err
		}
		tracks = append(tracks, t)
	}
	return tracks, nil
}

func (db *DB) GetPlaylistByName(name string) (*models.Playlist, error) {
	var p models.Playlist
	err := db.conn.QueryRow(`
		SELECT p.id, p.name, COUNT(pt.track_id)
		FROM playlists p
		LEFT JOIN playlist_tracks pt ON p.id = pt.playlist_id
		WHERE p.name = ?
		GROUP BY p.id
	`, name).Scan(&p.ID, &p.Name, &p.TrackCount)
	if err != nil {
		return nil, err
	}
	return &p, nil
}
