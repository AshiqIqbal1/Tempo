package main

import "log"
import "net/http"

func streamHandler(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "test.mp3")
}

func main() {
	http.HandleFunc("/stream", streamHandler)

	log.Println("Server is running on port 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
