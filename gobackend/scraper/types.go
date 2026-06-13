package scraper

type Event struct {
	ID           string   `json:"id"`
	Title        string   `json:"title"`
	Category     string   `json:"category"`
	Date         string   `json:"date"`
	Time         string   `json:"time"`
	StreamURL    string   `json:"stream_url"`
	EmbedURL     string   `json:"embed_url"`
	Language     string   `json:"language"`
	IsLive       bool     `json:"is_live"`
	IsActive     bool     `json:"is_active"`
	Quality      string   `json:"quality"`
	ThumbnailURL string   `json:"thumbnail_url"`
	AdFree       bool     `json:"ad_free"`
	FallbackURLs []string `json:"fallback_urls,omitempty"`
}

func (e Event) playURL() string {
	if e.StreamURL != "" {
		return e.StreamURL
	}
	return e.EmbedURL
}

type Channel struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	StreamURL    string   `json:"stream_url"`
	EmbedURL     string   `json:"embed_url"`
	IsActive     bool     `json:"is_active"`
	Quality      string   `json:"quality"`
	AdFree       bool     `json:"ad_free"`
	Language     string   `json:"language"`
	FallbackURLs []string `json:"fallback_urls,omitempty"`
}

type StreamStatus struct {
	URL      string `json:"url"`
	IsActive bool   `json:"is_active"`
	Latency  int    `json:"latency_ms"`
	Error    string `json:"error,omitempty"`
}

type channelStatusRaw struct {
	Canal  string `json:"Canal"`
	Estado string `json:"Estado"`
}

type eventoRaw struct {
	Title    string `json:"title"`
	Time     string `json:"time"`
	Category string `json:"category"`
	Language string `json:"language"`
	Link     string `json:"link"`
	Status   string `json:"status"`
	Date     string `json:"date,omitempty"`
}
