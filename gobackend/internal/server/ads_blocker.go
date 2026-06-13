package server

import (
	"io"
	"net/http"
	"strings"
	"time"

	"futbolgo/scraper"
)

func IsClickableAd(htmlContent string) bool {
	content := strings.ToLower(htmlContent)

	popupIndicators := []string{
		"popup", "modal", "overlay", "lightbox",
		"clickable", "clickthrough", "click-ad",
		"close-button", "close-ad", "exit-ad",
	}

	for _, indicator := range popupIndicators {
		if strings.Contains(content, indicator) {
			return true
		}
	}

	if strings.Contains(content, `data-ad-slot`) ||
		strings.Contains(content, `data-ad-client`) ||
		strings.Contains(content, `data-ad-format`) ||
		strings.Contains(content, `window.top !== window.self`) {
		return true
	}

	return false
}

func SanitizeHTML(content string) string {
	lines := strings.Split(content, "\n")
	var filteredLines []string

	for _, line := range lines {
		if scraper.IsAdContent(line) {
			continue
		}

		if strings.Contains(strings.ToLower(line), "script") &&
			(strings.Contains(strings.ToLower(line), "google") ||
				strings.Contains(strings.ToLower(line), "facebook") ||
				strings.Contains(strings.ToLower(line), "analytics")) {
			continue
		}

		if strings.Contains(strings.ToLower(line), "iframe") &&
			scraper.IsAdDomain(line) {
			continue
		}

		filteredLines = append(filteredLines, line)
	}

	return strings.Join(filteredLines, "\n")
}

func ProxyRequest(targetURL string, timeout time.Duration) (string, error) {
	client := &http.Client{
		Timeout: timeout,
	}

	req, err := http.NewRequest("GET", targetURL, nil)
	if err != nil {
		return "", err
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	req.Header.Set("Accept-Language", "es-ES,es;q=0.9")
	req.Header.Set("Accept-Encoding", "gzip, deflate")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	content := string(body)

	if strings.Contains(resp.Header.Get("Content-Type"), "text/html") {
		content = SanitizeHTML(content)
	}

	return content, nil
}

func BlockClickableAds(htmlContent string) map[string]interface{} {
	result := map[string]interface{}{
		"has_ads":     IsClickableAd(htmlContent),
		"ads_blocked": 0,
		"is_safe":     true,
		"timestamp":   time.Now().Unix(),
	}

	lines := strings.Split(htmlContent, "\n")
	adCount := 0

	for _, line := range lines {
		if scraper.IsAdContent(line) {
			adCount++
		}
	}

	result["ads_blocked"] = adCount
	result["is_safe"] = adCount == 0

	return result
}