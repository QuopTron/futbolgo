package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"futbolgo/scraper"
)

type Server struct {
	Host string
	Port int
}

type Response struct {
	Success   bool        `json:"success"`
	Data      interface{} `json:"data,omitempty"`
	Error     string      `json:"error,omitempty"`
	Timestamp int64       `json:"timestamp"`
}

func NewServer(host string, port int) *Server {
	return &Server{
		Host: host,
		Port: port,
	}
}

func writeJSON(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(data)
}

func NewResponse(success bool, data interface{}, errMsg string) Response {
	return Response{
		Success:   success,
		Data:      data,
		Error:     errMsg,
		Timestamp: time.Now().Unix(),
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, NewResponse(true, map[string]string{
		"status": "OK",
	}, ""))
}

func (s *Server) handleResolveStream(w http.ResponseWriter, r *http.Request) {
	streamURL := r.URL.Query().Get("url")
	if streamURL == "" {
		writeJSON(w, http.StatusBadRequest, NewResponse(false, nil, "URL requerida"))
		return
	}
	result := scraper.ResolveStreamFromURL(streamURL)
	var data interface{}
	json.Unmarshal([]byte(result), &data)
	writeJSON(w, http.StatusOK, NewResponse(true, data, ""))
}

func (s *Server) handleCheckStream(w http.ResponseWriter, r *http.Request) {
	streamURL := r.URL.Query().Get("url")
	if streamURL == "" {
		writeJSON(w, http.StatusBadRequest, NewResponse(false, nil, "URL de stream requerida"))
		return
	}
	if scraper.IsAdDomain(streamURL) || scraper.IsAdContent(streamURL) {
		writeJSON(w, http.StatusOK, NewResponse(false, map[string]interface{}{
			"blocked": true,
			"reason":  "Dominio bloqueado por anuncios",
		}, ""))
		return
	}
	writeJSON(w, http.StatusOK, NewResponse(true, map[string]interface{}{
		"url":    streamURL,
		"active": true,
		"safe":   true,
	}, ""))
}

func (s *Server) handleGetStreamInfo(w http.ResponseWriter, r *http.Request) {
	streamURL := r.URL.Query().Get("url")
	if streamURL == "" {
		writeJSON(w, http.StatusBadRequest, NewResponse(false, nil, "URL requerida"))
		return
	}
	info := map[string]interface{}{
		"url":        streamURL,
		"has_ads":    scraper.IsAdContent(streamURL),
		"is_blocked": scraper.IsAdDomain(streamURL),
		"safe":       !scraper.IsAdDomain(streamURL) && !scraper.IsAdContent(streamURL),
		"timestamp":  time.Now().Unix(),
	}
	writeJSON(w, http.StatusOK, NewResponse(true, info, ""))
}

func (s *Server) handleScrapeEvents(w http.ResponseWriter, r *http.Request) {
	result := scraper.ScrapeEvents()
	var data interface{}
	json.Unmarshal([]byte(result), &data)
	writeJSON(w, http.StatusOK, NewResponse(true, data, ""))
}

func (s *Server) handleScrapeChannels(w http.ResponseWriter, r *http.Request) {
	result := scraper.ScrapeChannels()
	var data interface{}
	json.Unmarshal([]byte(result), &data)
	writeJSON(w, http.StatusOK, NewResponse(true, data, ""))
}

func (s *Server) handleScrapeAll(w http.ResponseWriter, r *http.Request) {
	result := scraper.ScrapeAll()
	var data interface{}
	json.Unmarshal([]byte(result), &data)
	writeJSON(w, http.StatusOK, NewResponse(true, data, ""))
}

func (s *Server) handleFilterAds(w http.ResponseWriter, r *http.Request) {
	dataJSON := r.URL.Query().Get("data")
	if dataJSON == "" {
		writeJSON(w, http.StatusBadRequest, NewResponse(false, nil, "Parámetro 'data' requerido"))
		return
	}
	result := scraper.FilterAdStreams(dataJSON)
	var data interface{}
	json.Unmarshal([]byte(result), &data)
	writeJSON(w, http.StatusOK, NewResponse(true, data, ""))
}

func (s *Server) handleOptions(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.WriteHeader(http.StatusOK)
}

func (s *Server) RegisterRoutes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/api/resolve-stream", s.handleResolveStream)
	mux.HandleFunc("/api/check-stream", s.handleCheckStream)
	mux.HandleFunc("/api/stream-info", s.handleGetStreamInfo)
	mux.HandleFunc("/api/scrape/events", s.handleScrapeEvents)
	mux.HandleFunc("/api/scrape/channels", s.handleScrapeChannels)
	mux.HandleFunc("/api/scrape/all", s.handleScrapeAll)
	mux.HandleFunc("/api/scrape/filter-ads", s.handleFilterAds)
	mux.HandleFunc("/", s.handleOptions)
	return mux
}

func (s *Server) Start() error {
	mux := s.RegisterRoutes()
	addr := fmt.Sprintf("%s:%d", s.Host, s.Port)
	fmt.Printf("Servidor FutbolGO iniciado en http://%s\n", addr)
	return http.ListenAndServe(addr, mux)
}

func (s *Server) StartTLS(certFile, keyFile string) error {
	mux := s.RegisterRoutes()
	addr := fmt.Sprintf("%s:%d", s.Host, s.Port)
	fmt.Printf("Servidor HTTPS iniciado en https://%s\n", addr)
	return http.ListenAndServeTLS(addr, certFile, keyFile, mux)
}
