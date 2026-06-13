package main

import (
	"log"
	"futbolgo/internal/server"
)

func main() {
	s := server.NewServer("0.0.0.0", 8080)
	if err := s.Start(); err != nil {
		log.Fatal(err)
	}
}
