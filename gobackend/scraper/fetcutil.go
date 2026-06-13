package scraper

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

func newClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return fmt.Errorf("too many redirects")
			}
			return nil
		},
	}
}

func fetchURL(urlStr string) (string, error) {
	client := newClient(Timeout)
	req, err := http.NewRequest("GET", urlStr, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", UserAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "es-ES,es;q=0.9,en;q=0.8")
	req.Header.Set("Referer", BaseURL)

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(body), nil
}

func fetchJSON(urlStr string, target interface{}) error {
	client := newClient(Timeout)
	req, err := http.NewRequest("GET", urlStr, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", UserAgent)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Referer", BaseURL)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d al obtener %s", resp.StatusCode, urlStr)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	return json.Unmarshal(body, target)
}

func isAdFree(urlStr string) bool {
	if urlStr == "" {
		return true
	}
	return !IsAdDomain(urlStr) && !IsAdContent(urlStr)
}

func fetchChannelStatus() (map[string]bool, error) {
	var raw []channelStatusRaw
	err := fetchJSON(StatusURL, &raw)
	if err != nil {
		return nil, err
	}

	status := make(map[string]bool)
	for _, s := range raw {
		status[strings.ToLower(s.Canal)] = s.Estado == "Activo"
	}
	return status, nil
}

func extractStreamID(streamURL string) string {
	parsed, err := url.Parse(streamURL)
	if err != nil {
		return ""
	}
	return parsed.Query().Get("stream")
}
