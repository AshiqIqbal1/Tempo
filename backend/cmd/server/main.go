package main

import (
	"log"
	"net/http"
	"os"

	"github.com/AshiqIqbal1/Tempo/backend/internal/api"
	"github.com/AshiqIqbal1/Tempo/backend/internal/db"
	"github.com/AshiqIqbal1/Tempo/backend/internal/scanner"
)

func main() {
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "./tempo.db"
	}
	database, err := db.New(dbPath)
	if err != nil {
		log.Fatalf("Failing to create a new database: %v", err)
		return
	}

	musicDir := os.Getenv("MUSIC_DIR")
	router := api.NewRouter(database, musicDir)

	// Scan in background so API is available immediately
	go func() {
		log.Println("Scanning music directory...")
		err := scanner.Scan(musicDir, database)
		if err != nil {
			log.Printf("Scan error: %v", err)
		}
		log.Println("Scan complete.")
	}()

	log.Println("Server is running on port 8081...")
	log.Fatal(http.ListenAndServe(":8081", router))

}
