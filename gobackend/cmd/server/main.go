package main

import (
	"flag"
	"fmt"
	"log"

	"futbolgo/internal/server"
)

func main() {
	host := flag.String("host", "0.0.0.0", "Host del servidor")
	port := flag.Int("port", 8080, "Puerto del servidor")
	tlsCert := flag.String("cert", "", "Ruta del certificado TLS (opcional)")
	tlsKey := flag.String("key", "", "Ruta de la llave TLS (opcional)")

	flag.Parse()

	fmt.Println(`
FutbolGO - Servidor Backend con AD-Blocker
	`)

	srv := server.NewServer(*host, *port)

	var err error
	if *tlsCert != "" && *tlsKey != "" {
		err = srv.StartTLS(*tlsCert, *tlsKey)
	} else {
		err = srv.Start()
	}

	if err != nil {
		log.Fatalf("Error iniciando servidor: %v", err)
	}
}