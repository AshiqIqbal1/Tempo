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

	err = scanner.Scan(os.Getenv("MUSIC_DIR"), database)
	if err != nil {
		log.Fatalf("Failing to scan music directory: %v", err)
		return
	}

	router := api.NewRouter(database)

	log.Println("Server is running on port 8081...")
	log.Fatal(http.ListenAndServe(":8081", router))

}
