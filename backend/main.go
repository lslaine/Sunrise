package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")
	dbHost := os.Getenv("DB_HOST")
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // fallback for local testing
	}

	missingVars := []string{}
	for _, v := range []string{"DB_USER", "DB_PASSWORD", "DB_NAME", "DB_HOST"} {
		if os.Getenv(v) == "" {
			missingVars = append(missingVars, v)
		}
	}
	if len(missingVars) > 0 {
		log.Fatalf("Missing required environment variables: %v", missingVars)
	}

	dsn := fmt.Sprintf("%s:%s@unix(%s)/%s", dbUser, dbPassword, dbHost, dbName)

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("DB connection error: %v", err)
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		log.Fatalf("DB ping error: %v", err)
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello, World from Sunrise + MySQL!")
	})

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "OK")
	})	

	log.Printf("DB_USER=%s, DB_NAME=%s, DB_HOST=%s, PORT=%s", dbUser, dbName, dbHost, os.Getenv("PORT"))

	fmt.Printf("Server starting on :%s...\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}	
}