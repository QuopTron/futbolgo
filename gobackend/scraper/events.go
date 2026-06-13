package scraper

import (
	"encoding/json"
	"regexp"
	"strings"
)

func ScrapeEvents() string {
	events, err := fetchEventosJSON()
	if err == nil && len(events) > 0 {
		b, _ := json.Marshal(events)
		return string(b)
	}

	html, err := fetchURL(EventsURL)
	if err != nil {
		return `[{"error":"` + err.Error() + `"}]`
	}

	events = extractEventsFromHTML(html)
	if len(events) > 0 {
		b, _ := json.Marshal(events)
		return string(b)
	}

	return `[]`
}

func extractEventsFromHTML(html string) []Event {
	var events []Event
	idx := 0

	eventBlockRe := regexp.MustCompile(`(?i)<div[^>]*class="[^"]*\bevent\b[^"]*"[^>]*>(.*?)</div>\s*</div>`)
	blocks := eventBlockRe.FindAllStringSubmatch(html, -1)

	for _, block := range blocks {
		if len(block) < 2 {
			continue
		}
		content := block[1]

		nameRe := regexp.MustCompile(`(?i)<div[^>]*class="[^"]*event-name[^"]*"[^>]*>(.*?)</div>`)
		nameMatch := nameRe.FindStringSubmatch(content)
		title := "Evento"
		if len(nameMatch) > 1 {
			title = strings.TrimSpace(stripTags(nameMatch[1]))
		}

		linkRe := regexp.MustCompile(`(?i)(?:iframe[^>]*src|embed[^>]*src|href)\s*=\s*["']([^"']+)["']`)
		linkMatch := linkRe.FindStringSubmatch(content)
		embedURL := ""
		if len(linkMatch) > 1 {
			embedURL = linkMatch[1]
		}

		idx++
		events = append(events, Event{
			ID:       "ev_" + string(idx),
			Title:    title,
			Category: "Deportes",
			IsLive:   false,
			IsActive: false,
			EmbedURL: embedURL,
			Language: "ES",
			Quality:  "HD",
			AdFree:   isAdFree(embedURL),
		})
	}

	return events
}
