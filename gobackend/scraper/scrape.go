package scraper

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
)

func ScrapeChannels() string {
	html, err := fetchURL(BaseURL)
	if err != nil {
		return `[{"error":"` + err.Error() + `"}]`
	}

	channelsMap := parseChannelsFromJS(html)
	if len(channelsMap) == 0 {
		return `[{"error":"no se pudieron extraer canales del HTML"}]`
	}

	statusMap, _ := fetchChannelStatus()

	var channels []Channel
	idx := 0
	for name, link := range channelsMap {
		idx++
		streamID := extractStreamID(link)
		isActive := statusMap[strings.ToLower(streamID)]

		ch := Channel{
			ID:           "ch_" + string(idx),
			Name:         name,
			StreamURL:    link,
			IsActive:     isActive,
			Quality:      "HD",
			AdFree:       isAdFree(link),
			Language:     getChannelLanguage(streamID),
			FallbackURLs: buildFallbackURLs(streamID),
		}
		channels = append(channels, ch)
	}

	b, _ := json.Marshal(channels)
	return string(b)
}

func ScrapeAll() string {
	var wg sync.WaitGroup
	var evJSON, chJSON string

	wg.Add(2)
	go func() { defer wg.Done(); evJSON = ScrapeEvents() }()
	go func() { defer wg.Done(); chJSON = ScrapeChannels() }()
	wg.Wait()

	var evTest, chTest json.RawMessage
	json.Unmarshal([]byte(evJSON), &evTest)
	json.Unmarshal([]byte(chJSON), &chTest)

	r := struct {
		Events   interface{} `json:"events"`
		Channels interface{} `json:"channels"`
	}{
		Events:   evTest,
		Channels: chTest,
	}

	b, _ := json.Marshal(r)
	return string(b)
}

func stripTags(s string) string {
	re := regexp.MustCompile(`<[^>]*>`)
	return re.ReplaceAllString(s, "")
}

func CheckStreamActive(streamURL string) string {
	start := time.Now()
	status := StreamStatus{URL: streamURL}

	client := &http.Client{Timeout: 8 * time.Second}
	req, err := http.NewRequest("HEAD", streamURL, nil)
	if err != nil {
		req, _ = http.NewRequest("GET", streamURL, nil)
	}
	if req != nil {
		req.Header.Set("User-Agent", UserAgent)
		resp, err := client.Do(req)
		if err != nil {
			status.IsActive = false
			status.Error = err.Error()
		} else {
			resp.Body.Close()
			status.IsActive = resp.StatusCode < 400
			status.Latency = int(time.Since(start).Milliseconds())
			if !status.IsActive {
				status.Error = "HTTP " + string(resp.StatusCode)
			}
		}
	}

	b, _ := json.Marshal(status)
	return string(b)
}
