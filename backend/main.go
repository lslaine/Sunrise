package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	_ "github.com/go-sql-driver/mysql"
)

var (
	firebaseAuth *auth.Client
	authOnce     sync.Once
	db           *sql.DB
	dbOnce       sync.Once
)

// Lazy init Firebase Auth
func getFirebaseAuth() *auth.Client {
	authOnce.Do(func() {
		log.Println("Initializing Firebase...")
		ctx := context.Background()
		app, err := firebase.NewApp(ctx, nil)
		if err != nil {
			log.Fatalf("Firebase init error: %v", err)
		}
		firebaseAuth, err = app.Auth(ctx)
		if err != nil {
			log.Fatalf("Firebase auth client init error: %v", err)
		}
	})
	return firebaseAuth
}

// Lazy init DB
func getDB() *sql.DB {
	dbOnce.Do(func() {
		log.Println("Connecting to database...")
		dbUser := os.Getenv("DB_USER")
		dbPassword := os.Getenv("DB_PASSWORD")
		dbName := os.Getenv("DB_NAME")
		dbHost := os.Getenv("DB_HOST")
		dsn := fmt.Sprintf("%s:%s@unix(%s)/%s", dbUser, dbPassword, dbHost, dbName)

		var err error
		db, err = sql.Open("mysql", dsn)
		if err != nil {
			log.Fatalf("DB open error: %v", err)
		}
		if err = db.Ping(); err != nil {
			log.Fatalf("DB ping error: %v", err)
		}
	})
	return db
}

// CORS handler
func setCORSHeaders(w http.ResponseWriter, r *http.Request) {
	origin := r.Header.Get("Origin")
	if origin != "" {
		w.Header().Set("Access-Control-Allow-Origin", origin)
	} else {
		w.Header().Set("Access-Control-Allow-Origin", "*")
	}
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
}

// Middleware for Firebase authentication only
func withAuth(handler func(w http.ResponseWriter, r *http.Request, userID string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		setCORSHeaders(w, r)

		authHeader := r.Header.Get("Authorization")
		log.Printf("Auth Header: %q\n", authHeader)
		if authHeader == "" || !strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
			http.Error(w, "Unauthorized - Missing or invalid token", http.StatusUnauthorized)
			return
		}

		idToken := strings.TrimSpace(authHeader[len("Bearer "):])

		// Validate Firebase ID token
		authClient := getFirebaseAuth()
		token, err := authClient.VerifyIDToken(r.Context(), idToken)
		if err != nil {
			log.Printf("Firebase token verification failed: %v", err)
			http.Error(w, "Unauthorized - Invalid Firebase token", http.StatusUnauthorized)
			return
		}

		email, _ := token.Claims["email"].(string)
		handler(w, r, email)
	}
}

// Test handler
func testHandler(w http.ResponseWriter, r *http.Request) {
	setCORSHeaders(w, r)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	fmt.Fprintln(w, "OK TEST")
}

// Main route dispatcher
func router(w http.ResponseWriter, r *http.Request) {
	log.Printf("Request path: %s", r.URL.Path)
	switch r.URL.Path {
	case "/":
		withAuth(func(w http.ResponseWriter, r *http.Request, userID string) {
			getDB()
			fmt.Fprintf(w, "Hello %s!\n", userID)
		})(w, r)
	default:
		http.NotFound(w, r)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting server on port %s...", port)

	// Explicit test route for Cloud Run
	http.HandleFunc("/test", testHandler)

	// Main route handler with CORS and router
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		setCORSHeaders(w, r)
		if r.Method == http.MethodOptions {
			log.Printf("Received OPTIONS request from origin: %s", r.Header.Get("Origin"))
			log.Printf("Access-Control-Request-Method: %s", r.Header.Get("Access-Control-Request-Method"))
			log.Printf("Access-Control-Request-Headers: %s", r.Header.Get("Access-Control-Request-Headers"))
			w.WriteHeader(http.StatusOK)
			return
		}

		log.Printf("Received %s request to %s", r.Method, r.URL.Path)
		router(w, r)
	})

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
